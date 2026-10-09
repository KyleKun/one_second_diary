import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/commands/clip_encoding.dart';
import 'package:one_second_diary/core/media/commands/clip_render_files.dart';
import 'package:one_second_diary/core/media/commands/probe_commands.dart';
import 'package:one_second_diary/core/media/commands/save_clip_command.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/policy/srt_codec.dart';
import 'package:one_second_diary/core/media/policy/stamp_font.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/rendered_clip.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/ffmpeg_statistics.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

import '../../support/support.dart';
import '../../support/track_1a/media_engine_harness.dart';
import '../../support/track_1a/scripted_ffmpeg_gateway.dart';

const StampStyle whiteNumeric = StampStyle(
  format: StampFormat.numeric,
  rgb: 0xFFFFFF,
  outline: true,
);

VideoRender videoRequest({
  required String sourcePath,
  bool fromRecording = true,
  String subtitles = '',
  ClipLocation location = const ClipLocation.off(),
  VideoOrientation orientation = VideoOrientation.landscape,
  bool mute = false,
}) => VideoRender(
  sourcePath: sourcePath,
  fromRecording: fromRecording,
  trimStartMs: 1200,
  trimEndMs: 2700,
  outputFileName: '2024-01-05.mp4',
  stampText: '01/05/2024',
  stampStyle: whiteNumeric,
  legacyStampFont: false,
  location: location,
  subtitles: subtitles,
  format: ClipFormat.legacy(orientation),
  albumLabel: 'Default',
  mute: mute,
);

/// The job folder a render used: where its subtitles file was.
String jobFolderOf(List<String> argv) => File(argv[1]).parent.path;

void main() {
  late AppPaths paths;
  late ScriptedFfmpegGateway ffmpeg;
  late MediaEngine engine;
  late String source;

  setUp(() async {
    paths = await createTestPaths();
    ffmpeg = ScriptedFfmpegGateway();
    engine = engineOver(ffmpeg: ffmpeg, paths: paths);
    source = '${paths.temporaryDir}/REC123.mp4';
  });

  test('renders a recording into scratch with the v1.7 save command, its '
      'text files in its own job folder', () async {
    final Map<String, String> scratchFiles = <String, String>{};
    ffmpeg.onExecute = (List<String> argv) async {
      for (final String name in <String>['subtitles.srt', 'date.txt']) {
        scratchFiles[name] = File(
          '${jobFolderOf(argv)}/$name',
        ).readAsStringSync();
      }
      await ffmpeg.writeOutput(argv);
    };
    ffmpeg.otherProbeOutput = 'audio\n'; // the saved clip, microphone on
    final VideoRender request = videoRequest(sourcePath: source);

    final RenderedClip clip = await engine.renderClip(request);

    final List<String> argv = ffmpeg.executed.single;
    final String job = jobFolderOf(argv);
    expect(job, startsWith('${paths.scratchDir}/'));
    expect(
      argv,
      SaveClipCommand.video(
        request,
        files: ClipRenderFiles(
          subtitles: '$job/subtitles.srt',
          font: StampFont.rubik.pathIn(paths),
          dateText: '$job/date.txt',
          locationText: '$job/location.txt',
          output: clip.tempPath,
        ),
        encoder: VideoEncoder.libx264,
        addSilentAudio: false,
      ),
    );
    expect(scratchFiles, <String, String>{
      'subtitles.srt': SrtCodec.emptyCue,
      'date.txt': '01/05/2024',
    });
    expect(clip.tempPath, startsWith('${paths.scratchDir}/'));
    expect(clip.tempPath, endsWith('/2024-01-05.mp4'));
    expect(File(clip.tempPath).existsSync(), isTrue);
    expect(Directory(job).existsSync(), isFalse, reason: 'job folder deleted');
    expect(
      clip,
      RenderedClip(
        tempPath: clip.tempPath,
        durationMs: 1500,
        hasSubtitleStream: false,
        width: 1920,
        height: 1080,
        hasAudio: true,
        fps: 30,
        channels: 1,
        pixelFormat: 'yuv420p',
        schema: ClipSchema.v15,
      ),
    );
  });

  // A gallery video without audio (a screen recording) gets a silent track,
  // or the movie concat breaks. Only gallery videos are probed.
  group('audio', () {
    test('a silent gallery video gets the anullsrc track, so the clip has '
        'audio without a second probe', () async {
      ffmpeg.probeOutputs[source] = '';

      final RenderedClip clip = await engine.renderClip(
        videoRequest(sourcePath: source, fromRecording: false),
      );

      expect(clip.hasAudio, isTrue);
      expect(ffmpeg.probed, <List<String>>[
        ProbeCommands.audioStream(source),
        ProbeCommands.keyframes(clip.tempPath),
      ]);
      expect(
        ffmpeg.executed.single,
        containsAllInOrder(<String>[
          ...ClipEncoding.silentAudioInput(AudioChannels.mono),
          '-shortest',
        ]),
      );
      expect(
        ffmpeg.executed.single,
        containsAllInOrder(<String>['-map', '2:a']),
      );
    });

    test('a gallery video with audio, or whose probe failed, keeps its own '
        'optional audio, as v1.7 did', () async {
      ffmpeg.probeOutputs[source] = 'audio\n';
      await engine.renderClip(
        videoRequest(sourcePath: source, fromRecording: false),
      );
      ffmpeg.probeResults.add(FakeFfmpegGateway.failure());
      await engine.renderClip(
        videoRequest(
          sourcePath: '${paths.temporaryDir}/other.mp4',
          fromRecording: false,
        ),
      );

      for (final List<String> argv in ffmpeg.executed) {
        expect(argv, isNot(contains('-shortest')));
        expect(argv, containsAllInOrder(<String>['-map', '1:a?']));
      }
    });

    test('a gallery video whose audio probe failed is read from the '
        'rendered clip; unknown when that probe fails too', () async {
      ffmpeg.probeResults
        ..add(FakeFfmpegGateway.failure())
        ..add(FakeFfmpegGateway.failure());

      final RenderedClip clip = await engine.renderClip(
        videoRequest(sourcePath: source, fromRecording: false),
      );

      expect(ffmpeg.probed, <List<String>>[
        ProbeCommands.audioStream(source),
        ProbeCommands.audioStream(clip.tempPath),
        ProbeCommands.keyframes(clip.tempPath),
      ]);
      expect(clip.hasAudio, isNull);
    });

    // `-map 1:a?` keeps a recording made without a microphone (a
    // native-camera clip) silent, so its audio is read from the rendered
    // file. The movie plan normalises a clip without audio; a clip claimed
    // to have audio would be joined as it is and break the movie's audio.
    test('a recording is never probed, as in v1.7; the rendered clip is, '
        'once, so a recording without a microphone is known silent', () async {
      final RenderedClip clip = await engine.renderClip(
        videoRequest(sourcePath: source),
      );

      expect(ffmpeg.probed, <List<String>>[
        ProbeCommands.audioStream(clip.tempPath),
        ProbeCommands.keyframes(clip.tempPath),
      ]);
      expect(clip.hasAudio, isFalse);
    });

    // A request saved without sound gets the silent track whatever the source holds, so
    // neither audio probe runs.
    test('a request saved without sound is known to have (a silent) audio '
        'track without a probe; only its keyframes are read', () async {
      final RenderedClip clip = await engine.renderClip(
        videoRequest(sourcePath: source, fromRecording: false, mute: true),
      );

      expect(ffmpeg.probed, <List<String>>[
        ProbeCommands.keyframes(clip.tempPath),
      ]);
      expect(clip.hasAudio, isTrue);
      expect(ffmpeg.executed.single, contains('-shortest'));
      expect(ffmpeg.executed.single, contains('synopsis=muted=1'));
    });
  });

  test('renders a photo with the v1.7 photo command, its subtitle cue '
      'spanning the whole clip', () async {
    String? srt;
    ffmpeg.onExecute = (List<String> argv) async {
      srt = File(argv[1]).readAsStringSync();
      await ffmpeg.writeOutput(argv);
    };
    final PhotoRender request = PhotoRender(
      photoPath: '${paths.temporaryDir}/IMG_0001.HEIC',
      durationSeconds: 1.5,
      outputFileName: '2024-01-05-2.mp4',
      stampText: '5 January 2024',
      stampStyle: whiteNumeric,
      legacyStampFont: false,
      location: const ClipLocation.off(),
      subtitles: 'Hello',
      format: const ClipFormat.legacy(VideoOrientation.portrait),
      albumLabel: 'Work',
    );

    final RenderedClip clip = await engine.renderClip(request);

    final List<String> argv = ffmpeg.executed.single;
    final String job = jobFolderOf(argv);
    expect(
      argv,
      SaveClipCommand.photo(
        request,
        files: ClipRenderFiles(
          subtitles: '$job/subtitles.srt',
          font: StampFont.rubik.pathIn(paths),
          dateText: '$job/date.txt',
          locationText: '$job/location.txt',
          output: clip.tempPath,
        ),
        encoder: VideoEncoder.libx264,
      ),
    );
    expect(srt, SrtCodec.encode('Hello', startMs: 0, endMs: 1500));
    expect(ffmpeg.probed, <List<String>>[
      ProbeCommands.keyframes(clip.tempPath),
    ], reason: 'photos always get anullsrc; only the D27 keyframe probe');
    expect(
      clip,
      RenderedClip(
        tempPath: clip.tempPath,
        durationMs: 1500,
        hasSubtitleStream: true,
        width: 1080,
        height: 1920,
        hasAudio: true,
        fps: 30,
        channels: 1,
        pixelFormat: 'yuv420p',
        schema: ClipSchema.v15,
      ),
    );
    expect(clip.tempPath, endsWith('/2024-01-05-2.mp4'));
  });

  test('a clip geotagged in Chinese: place file, subtitle cue relative to '
      'the trim, the Noto Sans SC font registered before the encode', () async {
    final Map<String, String> files = <String, String>{};
    List<String>? fontsAtEncode;
    ffmpeg.onExecute = (List<String> argv) async {
      for (final String name in <String>['subtitles.srt', 'location.txt']) {
        files[name] = File('${jobFolderOf(argv)}/$name').readAsStringSync();
      }
      fontsAtEncode = List<String>.of(ffmpeg.fontDirectories);
      await ffmpeg.writeOutput(argv);
    };

    await engine.renderClip(
      videoRequest(
        sourcePath: source,
        subtitles: 'Привет',
        location: const ClipLocation(
          enabled: true,
          text: '北京, 中国',
          latitude: 55.7558,
          longitude: 37.6173,
        ),
      ),
    );

    expect(files, <String, String>{
      'subtitles.srt': SrtCodec.encode('Привет', startMs: 1200, endMs: 2700),
      'location.txt': '北京, 中国\r',
    });
    // The font FILE is passed as the "directory".
    expect(fontsAtEncode, <String>[StampFont.notoSansSc.pathIn(paths)]);
    expect(
      ffmpeg.executed.single,
      contains('location=+55.7558+37.6173/北京, 中国'),
    );
  });

  test('a failed save throws VideoProcessingException and leaves nothing in '
      'scratch', () async {
    ffmpeg.executeResults.add(
      FakeFfmpegGateway.failure(returnCode: 1, logs: 'Invalid data found'),
    );

    await expectLater(
      engine.renderClip(videoRequest(sourcePath: source)),
      throwsA(
        isA<VideoProcessingException>()
            .having((VideoProcessingException e) => e.returnCode, 'code', 1)
            .having(
              (VideoProcessingException e) => e.logTail,
              'logTail',
              'Invalid data found',
            ),
      ),
    );
    expect(Directory(paths.scratchDir).listSync(recursive: true), isEmpty);

    // A session that ends "successfully" without an output file is a
    // failure too, never an empty clip to publish.
    ffmpeg.onExecute = null;
    await expectLater(
      engine.renderClip(videoRequest(sourcePath: source)),
      throwsA(isA<VideoProcessingException>()),
    );
    expect(Directory(paths.scratchDir).listSync(recursive: true), isEmpty);
  });

  test('cancelling stops the session, throws CancelledException and leaves '
      'no partial clip', () async {
    ffmpeg.holdExecutions = true;
    final CancelToken token = CancelToken();
    final Future<RenderedClip> saving = engine.renderClip(
      videoRequest(sourcePath: source),
      cancelToken: token,
    );
    while (ffmpeg.heldSessions.isEmpty) {
      await pumpEventQueue();
    }

    token.cancel();

    await expectLater(saving, throwsA(isA<CancelledException>()));
    expect(ffmpeg.cancelledSessions, <int>[1]);
    expect(Directory(paths.scratchDir).listSync(recursive: true), isEmpty);
  });

  group('progress', () {
    late FakeClock clock;

    setUp(() {
      clock = FakeClock(DateTime(2024, 1, 5, 10));
      ffmpeg = ScriptedFfmpegGateway(clock: clock);
      engine = engineOver(ffmpeg: ffmpeg, paths: paths, clock: clock);
    });

    FfmpegStatistics sample(int timeMs) => FfmpegStatistics(
      timeMs: timeMs,
      videoFrameNumber: timeMs * 30 ~/ 1000,
      size: 0,
      speed: 1,
    );

    // Divided by whole seconds, a 1.5 s clip would read 75 % at half-way and
    // a trim under one second would never report. A photo reports over the
    // photo length.
    test('is the output time over the exact trim or photo length, capped at '
        '99.9 %', () async {
      ClipRenderRequest video(int trimEndMs) => VideoRender(
        sourcePath: source,
        fromRecording: true,
        trimStartMs: 0,
        trimEndMs: trimEndMs,
        outputFileName: '2024-01-05.mp4',
        stampText: '01/05/2024',
        stampStyle: whiteNumeric,
        legacyStampFont: false,
        location: const ClipLocation.off(),
        subtitles: '',
        format: const ClipFormat.legacy(VideoOrientation.landscape),
        albumLabel: 'Default',
      );
      final PhotoRender photo = PhotoRender(
        photoPath: '${paths.temporaryDir}/IMG_0001.jpg',
        durationSeconds: 1.5,
        outputFileName: '2024-01-05.mp4',
        stampText: '01/05/2024',
        stampStyle: whiteNumeric,
        legacyStampFont: false,
        location: const ClipLocation.off(),
        subtitles: '',
        format: const ClipFormat.legacy(VideoOrientation.landscape),
        albumLabel: 'Default',
      );
      for (final (
            String name,
            ClipRenderRequest request,
            List<int> times,
            List<double> expected,
          )
          in <(String, ClipRenderRequest, List<int>, List<double>)>[
            (
              'a 1.5 s trim',
              video(1500),
              <int>[0, 375, 750, 1500, 1600],
              <double>[0.25, 0.5, 0.999, 0.999],
            ),
            ('a 0.9 s trim', video(900), <int>[450], <double>[0.5]),
            ('a 1.5 s photo', photo, <int>[750, 1500], <double>[0.5, 0.999]),
          ]) {
        ffmpeg.statistics = <FfmpegStatistics>[
          for (final int ms in times) sample(ms),
        ];
        final List<double> progress = <double>[];

        await engine.renderClip(request, onProgress: progress.add);

        expect(progress, expected, reason: name);
      }
    });
  });
}
