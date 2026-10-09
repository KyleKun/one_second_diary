import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/policy/encoder_catalog.dart';
import 'package:one_second_diary/core/media/policy/stamp_font.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/stamp_font_store.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/rendered_clip.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

import '../../support/support.dart';
import '../../support/track_1a/media_engine_harness.dart';
import '../../support/track_1a/scripted_ffmpeg_gateway.dart';

void main() {
  late AppPaths paths;
  late ScriptedFfmpegGateway ffmpeg;

  setUp(() async {
    paths = await createTestPaths();
    ffmpeg = ScriptedFfmpegGateway();
  });

  group('init', () {
    test('copies the Rubik stamp font (the larger ones wait for a clip that '
        'needs them) and removes the copies older versions made', () async {
      final List<File> legacy = <File>[
        for (final String name in StampFontStore.legacyFileNames)
          File('${paths.fontsDir}/$name')..createSync(recursive: true),
      ];
      final MediaEngine engine = engineOver(ffmpeg: ffmpeg, paths: paths);

      await engine.init();

      expect(
        File(StampFont.rubik.pathIn(paths)).readAsStringSync(),
        StampFont.rubik.assetKey,
      );
      expect(File(StampFont.yuseiMagic.pathIn(paths)).existsSync(), isFalse);
      expect(File(StampFont.notoSansSc.pathIn(paths)).existsSync(), isFalse);
      expect(legacy.where((File file) => file.existsSync()), isEmpty);
    });

    // A killed app leaves its last job folder and unpublished renders behind.
    test('empties the scratch folder left by an earlier launch', () async {
      final List<File> orphans = <File>[
        File('${paths.scratchDir}/job-123/subtitles.srt'),
        File('${paths.scratchDir}/out-456/2024-01-05.mp4'),
      ];
      for (final File orphan in orphans) {
        orphan.createSync(recursive: true);
      }
      final File normalised = File('${paths.normalizedDir}/copy.mp4')
        ..createSync(recursive: true);

      await engineOver(ffmpeg: ffmpeg, paths: paths).init();

      expect(orphans.where((File file) => file.existsSync()), isEmpty);
      expect(Directory(paths.scratchDir).listSync(), isEmpty);
      expect(
        normalised.existsSync(),
        isTrue,
        reason: 'the cache is not scratch',
      );
    });
  });

  test('a font that cannot be copied fails the save that needs it, not '
      'init', () async {
    final MediaEngine engine = engineOver(
      ffmpeg: ffmpeg,
      paths: paths,
      loadAsset: (String key) async => throw const FileSystemException('full'),
    );

    await engine.init();

    await expectLater(
      engine.renderClip(_recording(paths)),
      throwsA(isA<VideoProcessingException>()),
    );
    expect(ffmpeg.executed, isEmpty);
  });

  group('encoder', () {
    const String gplIos = '''
 V....D libx264              libx264 H.264 / AVC / MPEG-4 AVC (codec h264)
 V....D h264_videotoolbox    VideoToolbox H.264 Encoder (codec h264)
''';

    const ClipFormat legacy = ClipFormat.legacy(VideoOrientation.landscape);

    VideoRender recording() => _recording(paths);

    test(
      'comes from the probe: VideoToolbox on iOS even with libx264',
      () async {
        ffmpeg.encodersOutput = gplIos;

        await engineOver(
          ffmpeg: ffmpeg,
          paths: paths,
          isIOS: true,
        ).renderClip(recording());

        expect(
          ffmpeg.executed.single,
          containsAllInOrder(
            EncoderCatalog.argumentsFor(VideoEncoder.videoToolbox, legacy),
          ),
        );
      },
    );

    // The encoder follows the request's format, not the build alone. An HEVC profile on the
    // GPL Android build takes hevc_mediacodec with the format's bitrate and the hvc1 tag;
    // libx264 is for the legacy format only.
    test(
      'follows the format: HEVC takes the platform\'s HEVC encoder',
      () async {
        ffmpeg.encodersOutput =
            ' V....D libx264              libx264 H.264\n'
            ' V....D hevc_mediacodec      MediaCodec HEVC encoder\n';
        const ClipFormat hevc = ClipFormat(
          tier: ResolutionTier.p1080,
          orientation: VideoOrientation.landscape,
          codec: VideoCodec.hevc,
          fps: FrameRate.f30,
          channels: AudioChannels.stereo,
          range: DynamicRange.sdr,
        );
        final VideoRender request = VideoRender(
          sourcePath: '${paths.temporaryDir}/REC.mp4',
          fromRecording: true,
          trimStartMs: 0,
          trimEndMs: 1500,
          outputFileName: '2024-01-05.mp4',
          stampText: '01/05/2024',
          stampStyle: const StampStyle(
            format: StampFormat.numeric,
            rgb: 0xFFFFFF,
            outline: true,
          ),
          legacyStampFont: false,
          location: const ClipLocation.off(),
          subtitles: '',
          format: hevc,
          albumLabel: 'Default',
        );

        final RenderedClip clip = await engineOver(
          ffmpeg: ffmpeg,
          paths: paths,
        ).renderClip(request);

        expect(
          ffmpeg.executed.single,
          containsAllInOrder(<String>[
            '-c:v', 'hevc_mediacodec', '-b:v', '8000k', //
            '-pix_fmt', 'yuv420p', '-tag:v', 'hvc1',
          ]),
        );
        expect((clip.channels, clip.schema), (2, ClipSchema.v2));
      },
    );

    // A save before the probe ended would use the default, which an LGPL
    // Android build does not have.
    test('a job submitted before the probe ends waits for it', () async {
      ffmpeg
        ..encodersGate = Completer<void>()
        ..encodersOutput =
            ' V....D h264_mediacodec   MediaCodec H.264 encoder\n';
      final MediaEngine engine = engineOver(ffmpeg: ffmpeg, paths: paths);

      final Future<RenderedClip> saving = engine.renderClip(recording());
      await pumpEventQueue();
      expect(ffmpeg.executed, isEmpty);

      ffmpeg.encodersGate!.complete();
      await saving;

      expect(
        ffmpeg.executed.single,
        containsAllInOrder(
          EncoderCatalog.argumentsFor(VideoEncoder.mediaCodec, legacy),
        ),
      );
    });

    test('a failed probe falls back to the platform default and init still '
        'completes', () async {
      final MemoryLogSink log = MemoryLogSink();
      final MediaEngine engine = engineOver(
        ffmpeg: _EncodersFailing(),
        paths: paths,
        log: log,
      );

      await engine.init();
      await engine.renderClip(recording());

      expect(log.lines, contains(contains('Encoder probe failed')));
    });
  });
}

/// The encoder listing throws (a plugin error).
class _EncodersFailing extends ScriptedFfmpegGateway {
  @override
  Future<String> listEncoders() async =>
      throw StateError('MissingPluginException');
}

VideoRender _recording(AppPaths paths) => VideoRender(
  sourcePath: '${paths.temporaryDir}/REC.mp4',
  fromRecording: true,
  trimStartMs: 0,
  trimEndMs: 1500,
  outputFileName: '2024-01-05.mp4',
  stampText: '01/05/2024',
  stampStyle: const StampStyle(
    format: StampFormat.numeric,
    rgb: 0xFFFFFF,
    outline: true,
  ),
  legacyStampFont: false,
  location: const ClipLocation.off(),
  subtitles: '',
  format: const ClipFormat.legacy(VideoOrientation.landscape),
  albumLabel: 'Default',
);
