import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/commands/calibration_commands.dart';
import 'package:one_second_diary/core/media/commands/probe_commands.dart';
import 'package:one_second_diary/core/media/device_media_check.dart';
import 'package:one_second_diary/core/media/ffmpeg_runner.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/policy/encoder_catalog.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/device_media_check_result.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

import '../../support/support.dart';
import '../../support/track_1a/media_engine_harness.dart';
import '../../support/track_1a/scripted_ffmpeg_gateway.dart';

/// ffprobe JSON of a file whose video stream is [codec] at [width]×[height],
/// with its pixel format and colour transfer when given.
String probeJson({
  required String codec,
  required int width,
  required int height,
  double seconds = 1,
  String? pixelFormat,
  String? colorTransfer,
}) =>
    '{"streams": [{"codec_type": "video", "codec_name": "$codec", '
    '"width": $width, "height": $height, "r_frame_rate": "30/1"'
    '${pixelFormat == null ? '' : ', "pix_fmt": "$pixelFormat"'}'
    '${colorTransfer == null ? '' : ', "color_transfer": "$colorTransfer"'}'
    '}], '
    '"format": {"duration": "$seconds"}}';

/// [probeJson] of the output an HLG encode test really wrote: 10-bit
/// planes with the HLG transfer (unless the test says otherwise).
String hlgProbeJson(
  ClipFormat format, {
  String pixelFormat = 'yuv420p10le',
  String colorTransfer = 'arib-std-b67',
}) => probeJson(
  codec: format.codec.token,
  width: format.width,
  height: format.height,
  pixelFormat: pixelFormat,
  colorTransfer: colorTransfer,
);

void main() {
  late AppPaths paths;
  late FakeClock clock;
  late ScriptedFfmpegGateway ffmpeg;
  late MediaEngine engine;

  /// The GPL Android build: libx264 and MediaCodec for both codecs.
  const String gplAndroid =
      ' V....D libx264              libx264 H.264\n'
      ' V....D h264_mediacodec      MediaCodec H.264 encoder\n'
      ' V....D hevc_mediacodec      MediaCodec HEVC encoder\n';

  setUp(() async {
    paths = await createTestPaths();
    clock = FakeClock(DateTime(2024, 1, 5, 10));
    ffmpeg = ScriptedFfmpegGateway(clock: clock)..encodersOutput = gplAndroid;
    engine = engineOver(ffmpeg: ffmpeg, paths: paths, clock: clock);
  });

  /// Makes every encode test take [perTest] of wall time and answers its
  /// probe with the format it was asked for (the output really holds it).
  void encodesIn(Duration perTest) {
    ffmpeg.onExecute = (List<String> argv) async {
      clock.advance(perTest);
      await ffmpeg.writeOutput(argv);
    };
    for (final (int index, ClipFormat format)
        in DeviceMediaCheck.candidates.indexed) {
      ffmpeg.probeOutputs['encode-$index.mp4'] = format.isHdr
          ? hlgProbeJson(format)
          : probeJson(
              codec: format.codec.token,
              width: format.width,
              height: format.height,
            );
    }
  }

  // Every candidate passes at 2× real time: all nine run, in order (the
  // seven SDR ones, then the two HLG ones), with the catalogue's encoder
  // for each, and the sample is decoded.
  test('runs the candidates in escalation order with the format\'s encoder, '
      'times each against the clock, then decodes the samples', () async {
    encodesIn(const Duration(milliseconds: 500));
    final String sample = '${paths.temporaryDir}/iphone.mp4';
    ffmpeg.probeOutputs[sample] = probeJson(
      codec: 'h264',
      width: 3840,
      height: 2160,
      seconds: 0.5,
    );
    final List<(int, int)> progress = <(int, int)>[];
    final List<(int, Object)> started = <(int, Object)>[];

    final DeviceMediaCheckResult result = await engine.checkDevice(
      decodeSamples: <String>[sample],
      onProgress: (int done, int total) => progress.add((done, total)),
      onEncodeStart: (int index, ClipFormat format) =>
          started.add((index, format)),
      onDecodeStart: (int index, String sample) => started.add((index, sample)),
    );

    expect(result.encode, hasLength(DeviceMediaCheck.candidates.length));
    expect(
      result.encode.map((EncodeTestResult r) => r.format),
      DeviceMediaCheck.candidates,
    );
    expect(result.encode.map((EncodeTestResult r) => r.encoder), <VideoEncoder>[
      VideoEncoder.libx264,
      VideoEncoder.hevcMediaCodec,
      VideoEncoder.hevcMediaCodec,
      VideoEncoder.hevcMediaCodec,
      VideoEncoder.hevcMediaCodec,
      VideoEncoder.hevcMediaCodec,
      VideoEncoder.mediaCodec,
      VideoEncoder.hevcMediaCodec,
      VideoEncoder.hevcMediaCodec,
    ]);
    expect(result.encode.every((EncodeTestResult r) => r.ok), isTrue);
    expect(
      result.encode.map((EncodeTestResult r) => r.realtimeFactor),
      everyElement(2.0),
    );
    expect(result.decode, <DecodeTestResult>[
      DecodeTestResult(sample: sample, ok: true, realtimeFactor: 1.0),
    ]);
    expect(progress.first, (1, 10));
    expect(progress.last, (10, 10));
    // Each test is announced as it starts, with its step over the run: the
    // encodes first, then the decodes after the last candidate.
    expect(started, <(int, Object)>[
      for (final (int index, ClipFormat format)
          in DeviceMediaCheck.candidates.indexed)
        (index, format),
      (DeviceMediaCheck.candidates.length, sample),
    ]);
    // The argv of the first and the last encode test, and the decode.
    final String job = File(
      ScriptedFfmpegGateway.outputOf(ffmpeg.executed.first)!,
    ).parent.path;
    expect(job, startsWith('${paths.scratchDir}/'));
    expect(
      ffmpeg.executed.first,
      CalibrationCommands.encodeTest(
        format: DeviceMediaCheck.candidates.first,
        encoder: VideoEncoder.libx264,
        output: '$job/encode-0.mp4',
      ),
    );
    expect(
      ffmpeg.executed[6],
      CalibrationCommands.encodeTest(
        format: DeviceMediaCheck.candidates[6],
        encoder: VideoEncoder.mediaCodec,
        output: '$job/encode-6.mp4',
      ),
    );
    expect(
      ffmpeg.executed.last,
      CalibrationCommands.decodeTest(sample: sample),
    );
    expect(ffmpeg.probed.last, ProbeCommands.streams(sample));
    expect(Directory(paths.scratchDir).listSync(recursive: true), isEmpty);
  });

  // A weak phone: 1080p30 H.264 at 2×, 1080p30 HEVC at 0.4× stops the
  // escalation. The 4K tests never run.
  test('stops after a candidate under half real time; the later ones are '
      'not tried', () async {
    int runs = 0;
    ffmpeg.onExecute = (List<String> argv) async {
      runs++;
      clock.advance(
        runs == 1
            ? const Duration(milliseconds: 500)
            : const Duration(milliseconds: 2500),
      );
      await ffmpeg.writeOutput(argv);
    };
    for (final (int index, ClipFormat format)
        in DeviceMediaCheck.candidates.indexed) {
      ffmpeg.probeOutputs['encode-$index.mp4'] = probeJson(
        codec: format.codec.token,
        width: format.width,
        height: format.height,
      );
    }

    final List<int> started = <int>[];
    final DeviceMediaCheckResult result = await engine.checkDevice(
      decodeSamples: const <String>[],
      onEncodeStart: (int index, ClipFormat _) => started.add(index),
    );

    expect(
      result.encode.map((EncodeTestResult r) => r.realtimeFactor),
      <double>[2.0, 0.4],
    );
    expect(started, <int>[0, 1], reason: 'the later ones never start');
    expect(result.encode.every((EncodeTestResult r) => r.ok), isTrue);
    expect(ffmpeg.executed, hasLength(2));
    expect(result.encodeOf(DeviceMediaCheck.candidates[2]), isNull);
    expect(
      result.encodeOf(
        DeviceMediaCheck.candidates[1].withOrientation(
          VideoOrientation.portrait,
        ),
      ),
      result.encode[1],
      reason: 'the orientation does not change the answer',
    );
  });

  // The encoder list only says a wrapper was compiled in: a failed ffmpeg
  // session, or an output that is not the format asked for, is "not
  // supported" and stops the escalation too.
  test('a failed encode, or an output in another format, fails the '
      'candidate and stops', () async {
    encodesIn(const Duration(milliseconds: 500));
    ffmpeg.answer = (List<String> argv) =>
        argv.contains('hevc_mediacodec') ? FakeFfmpegGateway.failure() : null;

    final DeviceMediaCheckResult failed = await engine.checkDevice(
      decodeSamples: const <String>[],
    );

    expect(failed.encode.map((EncodeTestResult r) => r.ok), <bool>[
      true,
      false,
    ]);
    expect(failed.encode.last.realtimeFactor, 0);

    ffmpeg.answer = null;
    ffmpeg.executed.clear();
    // The HEVC "encoder" silently wrote H.264.
    ffmpeg.probeOutputs['encode-1.mp4'] = probeJson(
      codec: 'h264',
      width: 1920,
      height: 1080,
    );
    final DeviceMediaCheckResult wrong = await engine.checkDevice(
      decodeSamples: const <String>[],
    );
    expect(wrong.encode.map((EncodeTestResult r) => r.ok), <bool>[true, false]);
  });

  test('a sample that cannot be read or decoded fails its decode test '
      'without failing the check', () async {
    encodesIn(const Duration(milliseconds: 500));
    final String broken = '${paths.temporaryDir}/broken.mp4';
    final String slow = '${paths.temporaryDir}/slow.mp4';
    ffmpeg.probeOutputs[slow] = probeJson(
      codec: 'hevc',
      width: 3840,
      height: 2160,
      seconds: 0.5,
    );
    // Nothing scripted for the broken sample: ffprobe prints nothing
    // readable.

    final DeviceMediaCheckResult result = await engine.checkDevice(
      decodeSamples: <String>[broken, slow],
    );

    expect(result.decode, <DecodeTestResult>[
      DecodeTestResult(sample: broken, ok: false, realtimeFactor: 0),
      DecodeTestResult(sample: slow, ok: true, realtimeFactor: 1.0),
    ]);
  });

  // An encode test has a wall-time bound (`encodeTestTimeout`): a session
  // still running at the bound is cancelled through the gateway, scored
  // failed with factor 0, and the escalation stops there as for any
  // failure. The check itself answers; nothing throws.
  test('an encode test that never finishes is cut at the bound and scored '
      'failed; the next candidate is not run', () async {
    ffmpeg.holdExecutions = true;
    final DeviceMediaCheck check = DeviceMediaCheck(
      runner: FfmpegRunner(
        ffmpeg: ffmpeg,
        logger: memoryLogger(MemoryLogSink(), clock: clock),
      ),
      encoders: EncoderCatalog.of(gplAndroid, isIOS: false),
      clock: clock,
      logger: memoryLogger(MemoryLogSink(), clock: clock),
      testTimeout: const Duration(milliseconds: 20),
    );
    final Directory job = await Directory(
      '${paths.scratchDir}/check',
    ).create(recursive: true);

    final DeviceMediaCheckResult result = await check.run(
      job: job,
      decodeSamples: const <String>[],
    );

    expect(ffmpeg.cancelledSessions, <int>[
      1,
    ], reason: 'the session is stopped');
    expect(result.encode, <EncodeTestResult>[
      EncodeTestResult(
        format: DeviceMediaCheck.candidates.first,
        encoder: VideoEncoder.libx264,
        ok: false,
        realtimeFactor: 0,
      ),
    ]);
    expect(ffmpeg.executed, hasLength(1), reason: 'the escalation stops');
    expect(ffmpeg.probed, isEmpty, reason: 'no output to check');
  });

  test('cancelled between tests: CancelledException, nothing left in '
      'scratch', () async {
    final CancelToken token = CancelToken();
    int runs = 0;
    ffmpeg.onExecute = (List<String> argv) async {
      if (++runs == 2) token.cancel();
      clock.advance(const Duration(milliseconds: 500));
      await ffmpeg.writeOutput(argv);
    };
    for (final (int index, ClipFormat format)
        in DeviceMediaCheck.candidates.indexed) {
      ffmpeg.probeOutputs['encode-$index.mp4'] = probeJson(
        codec: format.codec.token,
        width: format.width,
        height: format.height,
      );
    }

    await expectLater(
      engine.checkDevice(decodeSamples: const <String>[], cancelToken: token),
      throwsA(isA<CancelledException>()),
    );
    expect(ffmpeg.executed, hasLength(2));
    expect(Directory(paths.scratchDir).listSync(recursive: true), isEmpty);
  });

  // The HLG candidates are gated by their tier's SDR HEVC test, not by the escalation, so
  // a phone whose 4K60 H.264 fails (no Level 5.2) still runs them; an output the wrapper
  // quietly wrote 8-bit, or tagged SDR, fails them.
  test('the HLG candidates run after their tier\'s SDR HEVC test passed, '
      'whatever the 4K60 H.264 test did; an 8-bit or SDR-tagged output '
      'fails them; a slow 4K30 HEVC skips 4K HLG alone', () async {
    encodesIn(const Duration(milliseconds: 500));
    ffmpeg.answer = (List<String> argv) =>
        argv.contains('h264_mediacodec') &&
            argv.any((String a) => a.contains('3840x2160'))
        ? FakeFfmpegGateway.failure()
        : null;
    final List<int> started = <int>[];

    final DeviceMediaCheckResult result = await engine.checkDevice(
      decodeSamples: const <String>[],
      onEncodeStart: (int index, ClipFormat _) => started.add(index),
    );

    expect(started, <int>[0, 1, 2, 3, 4, 5, 6, 7, 8]);
    expect(result.encode.map((EncodeTestResult r) => r.ok), <bool>[
      true, true, true, true, true, true, false, true, true, //
    ]);
    expect(result.encodeOf(DeviceMediaCheck.hlg1080)?.realtimeFactor, 2.0);
    expect(result.encodeOf(DeviceMediaCheck.hlg2160)?.realtimeFactor, 2.0);
    expect(
      DeviceMediaCheck.prerequisiteOf(DeviceMediaCheck.hlg2160),
      DeviceMediaCheck.candidates[4],
    );
    expect(
      DeviceMediaCheck.prerequisiteOf(DeviceMediaCheck.candidates[4]),
      isNull,
    );

    // The wrapper refused p010le and ffmpeg fell back to 8-bit at 1080p;
    // the 4K output carries no HLG transfer.
    ffmpeg.answer = null;
    ffmpeg.executed.clear();
    ffmpeg.probeOutputs['encode-7.mp4'] = hlgProbeJson(
      DeviceMediaCheck.hlg1080,
      pixelFormat: 'yuv420p',
    );
    ffmpeg.probeOutputs['encode-8.mp4'] = hlgProbeJson(
      DeviceMediaCheck.hlg2160,
      colorTransfer: 'bt709',
    );
    final DeviceMediaCheckResult eightBit = await engine.checkDevice(
      decodeSamples: const <String>[],
    );
    expect(eightBit.encodeOf(DeviceMediaCheck.hlg1080)?.ok, isFalse);
    expect(eightBit.encodeOf(DeviceMediaCheck.hlg2160)?.ok, isFalse);
    expect(eightBit.encode.take(7).every((EncodeTestResult r) => r.ok), isTrue);

    // 4K30 HEVC under half real time: the escalation stops there, 1080p
    // HLG still runs (its 1080p30 HEVC test passed), 4K HLG never does.
    int runs = 0;
    ffmpeg.onExecute = (List<String> argv) async {
      runs++;
      clock.advance(
        runs == 5
            ? const Duration(milliseconds: 2500)
            : const Duration(milliseconds: 500),
      );
      await ffmpeg.writeOutput(argv);
    };
    ffmpeg.probeOutputs['encode-7.mp4'] = hlgProbeJson(
      DeviceMediaCheck.hlg1080,
    );
    started.clear();
    final DeviceMediaCheckResult slow4k = await engine.checkDevice(
      decodeSamples: const <String>[],
      onEncodeStart: (int index, ClipFormat _) => started.add(index),
    );
    expect(started, <int>[0, 1, 2, 3, 4, 7]);
    expect(slow4k.encodeOf(DeviceMediaCheck.hlg1080)?.ok, isTrue);
    expect(slow4k.encodeOf(DeviceMediaCheck.hlg2160), isNull);
  });
}
