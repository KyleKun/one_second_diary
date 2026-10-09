import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/commands/calibration_commands.dart';
import 'package:one_second_diary/core/media/commands/probe_commands.dart';
import 'package:one_second_diary/core/media/ffmpeg_runner.dart';
import 'package:one_second_diary/core/media/policy/clip_probe_parser.dart';
import 'package:one_second_diary/core/media/policy/encoder_catalog.dart';
import 'package:one_second_diary/core/media/policy/movie_plan.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/color_transfer.dart';
import 'package:one_second_diary/core/media/types/device_media_check_result.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/ffmpeg_result.dart';

/// The ffmpeg half of the phone check, run
/// inside one media job by `MediaEngine.checkDevice`: the encode
/// [candidates] in escalation order, each one second of a test pattern
/// encoded with the format's real settings and timed with the clock, then
/// the software decode of each bundled sample. Cancellable between jobs.
/// The camera probe and the free space are the other lanes' and never run
/// here.
final class DeviceMediaCheck {
  DeviceMediaCheck({
    required this._runner,
    required this._encoders,
    required this._clock,
    required this._logger,
    Duration testTimeout = encodeTestTimeout,
  }) : _timeout = testTimeout;

  static const String _tag = 'ffmpeg';

  /// The encode candidates, cheapest first: the
  /// SDR escalation, where a candidate that fails or runs under
  /// [stopBelowFactor] stops the tiers above it, so a weak phone never
  /// runs the 4K tests (720p is assumed when 1080p works); then the two
  /// HLG candidates, each gated by the SDR HEVC test of its tier instead
  /// ([prerequisiteOf]): 1080p HLG runs when 1080p30 HEVC passed, 2160p
  /// HLG when 2160p30 HEVC passed, whatever the 2160p60 tests did.
  static const List<ClipFormat> candidates = <ClipFormat>[
    ClipFormat.legacy(VideoOrientation.landscape),
    ClipFormat(
      tier: ResolutionTier.p1080,
      orientation: VideoOrientation.landscape,
      codec: VideoCodec.hevc,
      fps: FrameRate.f30,
      channels: AudioChannels.stereo,
      range: DynamicRange.sdr,
    ),
    ClipFormat(
      tier: ResolutionTier.p1080,
      orientation: VideoOrientation.landscape,
      codec: VideoCodec.hevc,
      fps: FrameRate.f60,
      channels: AudioChannels.stereo,
      range: DynamicRange.sdr,
    ),
    ClipFormat(
      tier: ResolutionTier.p1440,
      orientation: VideoOrientation.landscape,
      codec: VideoCodec.hevc,
      fps: FrameRate.f30,
      channels: AudioChannels.stereo,
      range: DynamicRange.sdr,
    ),
    ClipFormat(
      tier: ResolutionTier.p2160,
      orientation: VideoOrientation.landscape,
      codec: VideoCodec.hevc,
      fps: FrameRate.f30,
      channels: AudioChannels.stereo,
      range: DynamicRange.sdr,
    ),
    ClipFormat(
      tier: ResolutionTier.p2160,
      orientation: VideoOrientation.landscape,
      codec: VideoCodec.hevc,
      fps: FrameRate.f60,
      channels: AudioChannels.stereo,
      range: DynamicRange.sdr,
    ),
    ClipFormat(
      tier: ResolutionTier.p2160,
      orientation: VideoOrientation.landscape,
      codec: VideoCodec.h264,
      fps: FrameRate.f60,
      channels: AudioChannels.stereo,
      range: DynamicRange.sdr,
    ),
    hlg1080,
    hlg2160,
  ];

  /// HLG 10-bit HEVC at 1080p30.
  static const ClipFormat hlg1080 = ClipFormat(
    tier: ResolutionTier.p1080,
    orientation: VideoOrientation.landscape,
    codec: VideoCodec.hevc,
    fps: FrameRate.f30,
    channels: AudioChannels.stereo,
    range: DynamicRange.hlg,
  );

  /// HLG 10-bit HEVC at 2160p30.
  static const ClipFormat hlg2160 = ClipFormat(
    tier: ResolutionTier.p2160,
    orientation: VideoOrientation.landscape,
    codec: VideoCodec.hevc,
    fps: FrameRate.f30,
    channels: AudioChannels.stereo,
    range: DynamicRange.hlg,
  );

  /// The SDR candidate that must have passed before [format] runs: the
  /// HEVC 30 fps test of its tier for an HLG candidate; null for an SDR
  /// one (the escalation order gates those).
  static ClipFormat? prerequisiteOf(ClipFormat format) =>
      format.range == DynamicRange.hlg
      ? ClipFormat(
          tier: format.tier,
          orientation: format.orientation,
          codec: VideoCodec.hevc,
          fps: FrameRate.f30,
          channels: AudioChannels.stereo,
          range: DynamicRange.sdr,
        )
      : null;

  /// Below this real-time factor a candidate stops the escalation: the
  /// next tiers would only be slower.
  static const double stopBelowFactor = 0.5;

  /// The wall time an encode test may take: one that is not done by then
  /// is cancelled and scored failed (factor 0), which stops the escalation
  /// like any failure. One second of video under [stopBelowFactor] takes
  /// two seconds; a software fallback at 4K60 can run for a minute, and a
  /// phone that slow would never save in reasonable time anyway.
  static const Duration encodeTestTimeout = Duration(seconds: 5);

  final FfmpegRunner _runner;
  final EncoderCatalog _encoders;
  final Clock _clock;
  final AppLogger _logger;

  /// [encodeTestTimeout] unless a test shortens it.
  final Duration _timeout;

  /// Runs the check in [job]'s folder: every candidate until one fails or
  /// runs under [stopBelowFactor], then every sample of [decodeSamples].
  /// [onProgress] is told the tests done over the tests there would be at
  /// most; [onEncodeStart] and [onDecodeStart] are told each test as it
  /// starts, with its 0-based step over the whole run (the encodes first,
  /// then the decodes from `candidates.length`), for a progress line.
  Future<DeviceMediaCheckResult> run({
    required Directory job,
    required List<String> decodeSamples,
    CancelToken? cancelToken,
    void Function(int done, int total)? onProgress,
    void Function(int index, ClipFormat format)? onEncodeStart,
    void Function(int index, String sample)? onDecodeStart,
  }) async {
    final int total = candidates.length + decodeSamples.length;
    int done = 0;
    void step() => onProgress?.call(++done, total);

    final List<EncodeTestResult> encode = <EncodeTestResult>[];
    bool escalating = true;
    bool passed(ClipFormat format) {
      for (final EncodeTestResult result in encode) {
        if (result.format == format) {
          return result.ok && result.realtimeFactor >= stopBelowFactor;
        }
      }
      return false;
    }

    for (final (int index, ClipFormat format) in candidates.indexed) {
      cancelToken?.throwIfCancelled();
      final ClipFormat? prerequisite = prerequisiteOf(format);
      // An HLG candidate runs only after its tier's SDR HEVC test passed;
      // an SDR one only while the escalation has not stopped. A candidate
      // not run has no result (`encodeOf` null: never tested).
      if (prerequisite == null ? !escalating : !passed(prerequisite)) {
        continue;
      }
      onEncodeStart?.call(index, format);
      final EncodeTestResult result = await _encodeTest(
        format,
        output: '${job.path}/encode-$index.mp4',
        cancelToken: cancelToken,
      );
      encode.add(result);
      step();
      if (prerequisite == null &&
          (!result.ok || result.realtimeFactor < stopBelowFactor)) {
        _logger.info(_tag, 'Phone check stops at $format');
        escalating = false;
      }
    }
    final List<DecodeTestResult> decode = <DecodeTestResult>[];
    for (final (int index, String sample) in decodeSamples.indexed) {
      cancelToken?.throwIfCancelled();
      onDecodeStart?.call(candidates.length + index, sample);
      decode.add(await _decodeTest(sample));
      step();
    }
    return DeviceMediaCheckResult(encode: encode, decode: decode);
  }

  /// One second of [format] encoded into [output]: ok when ffmpeg
  /// finished within [_timeout] and the output's video stream is the
  /// format's codec and canvas; the factor is the second over the wall
  /// time.
  ///
  /// That wall time includes ffmpeg's start-up (the session spawn, the
  /// test pattern's filter graph, the encoder's open: a few hundred
  /// milliseconds, the hardware encoders' the longest), a fixed share
  /// that weighs on the fast tiers most. Nothing is subtracted for it: a
  /// real save pays it too, so the factor is a conservative floor, never
  /// a promise a save then misses.
  ///
  /// A test that outruns [_timeout] is cancelled through its own token
  /// (the caller's [cancelToken] cancels it too, and still throws).
  Future<EncodeTestResult> _encodeTest(
    ClipFormat format, {
    required String output,
    required CancelToken? cancelToken,
  }) async {
    final VideoEncoder encoder = _encoders.encoderFor(format);
    _logger.info(_tag, 'Phone check: $format with ${encoder.ffmpegName}');
    final CancelToken bound = CancelToken();
    unawaited(cancelToken?.whenCancelled.then((_) => bound.cancel()));
    final Timer timer = Timer(_timeout, bound.cancel);
    final DateTime started = _clock.now();
    final FfmpegResult result;
    try {
      result = await _runner.attempt(
        CalibrationCommands.encodeTest(
          format: format,
          encoder: encoder,
          output: output,
        ),
        job: 'Encode test $format',
        cancelToken: bound,
      );
    } on CancelledException {
      cancelToken?.throwIfCancelled();
      _logger.info(
        _tag,
        'Phone check: $format not done in ${_timeout.inSeconds} s',
      );
      return EncodeTestResult(
        format: format,
        encoder: encoder,
        ok: false,
        realtimeFactor: 0,
      );
    } finally {
      timer.cancel();
    }
    final int elapsedMs = _clock.now().difference(started).inMilliseconds;
    cancelToken?.throwIfCancelled();
    final bool ok = result.success && await _wrote(format, output);
    return EncodeTestResult(
      format: format,
      encoder: encoder,
      ok: ok,
      realtimeFactor: ok ? _factor(1000, elapsedMs) : 0,
    );
  }

  /// Whether the file at [output] holds [format]'s codec and canvas and,
  /// for an HLG candidate, 10-bit planes with the HLG transfer: ffmpeg
  /// falls back to 8-bit when a hardware wrapper refuses the 10-bit
  /// input (`ClipEncoding.hlgPixelFormat`), still tagging the file HLG,
  /// and such a phone must not be told it writes HLG.
  Future<bool> _wrote(ClipFormat format, String output) async {
    try {
      final ClipProbe probe = ClipProbeParser.parse(
        await _runner.probe(
          ProbeCommands.streams(output),
          job: 'Probe of the encode test $format',
        ),
      );
      final bool hlg =
          format.range != DynamicRange.hlg ||
          (probe.pixelFormat == MoviePlan.pixelFormatOf(format) &&
              probe.colorTransfer == ColorTransfer.hlg);
      return probe.codec == format.codec.token &&
          probe.width == format.width &&
          probe.height == format.height &&
          hlg;
    } on VideoProcessingException {
      return false;
    } on FormatException {
      return false;
    }
  }

  /// [sample] decoded in software: the factor is its length over the wall
  /// time; a sample ffprobe cannot read, or ffmpeg cannot decode, fails.
  Future<DecodeTestResult> _decodeTest(String sample) async {
    final int? durationMs = await _durationOf(sample);
    if (durationMs == null || durationMs <= 0) {
      return DecodeTestResult(sample: sample, ok: false, realtimeFactor: 0);
    }
    final DateTime started = _clock.now();
    final FfmpegResult result = await _runner.attempt(
      CalibrationCommands.decodeTest(sample: sample),
      job: 'Decode test $sample',
    );
    final int elapsedMs = _clock.now().difference(started).inMilliseconds;
    return DecodeTestResult(
      sample: sample,
      ok: result.success,
      realtimeFactor: result.success ? _factor(durationMs, elapsedMs) : 0,
    );
  }

  Future<int?> _durationOf(String sample) async {
    try {
      return ClipProbeParser.parse(
        await _runner.probe(
          ProbeCommands.streams(sample),
          job: 'Probe of the decode sample $sample',
        ),
      ).durationMs;
    } on VideoProcessingException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// [videoMs] of video over [elapsedMs] of wall time; a wall time under
  /// a millisecond counts as one.
  static double _factor(int videoMs, int elapsedMs) =>
      videoMs / math.max(1, elapsedMs);
}
