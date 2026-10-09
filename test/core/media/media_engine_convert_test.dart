// "Convert into a new profile" at the engine: one queued job that runs
// `ConvertClipCommand` with the format's encoder into an `out-*` folder of scratch, reads
// the output's audio and keyframes once (so the new clip's cached facts are true and a
// movie needs no probe), and reports the format's facts; a failed session leaves nothing.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/commands/convert_clip_command.dart';
import 'package:one_second_diary/core/media/commands/probe_commands.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/rendered_clip.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

import '../../support/support.dart';
import '../../support/track_1a/media_engine_harness.dart';
import '../../support/track_1a/scripted_ffmpeg_gateway.dart';

const ClipFormat ultra = ClipFormat(
  tier: ResolutionTier.p2160,
  orientation: VideoOrientation.landscape,
  codec: VideoCodec.hevc,
  fps: FrameRate.f60,
  channels: AudioChannels.stereo,
  range: DynamicRange.sdr,
);

/// Two keyframes 20 frames from each end of a 90-frame clip at 60 fps.
const String keyframePackets =
    '0.000000,K_\n'
    '0.016667,__\n'
    '0.333333,K_\n'
    '1.166667,K_\n';

void main() {
  late AppPaths paths;
  late ScriptedFfmpegGateway ffmpeg;
  late MediaEngine engine;
  late String source;

  setUp(() async {
    paths = await createTestPaths();
    ffmpeg = ScriptedFfmpegGateway()
      ..encodersOutput =
          ' V....D libx264              libx264 H.264\n'
          ' V....D hevc_mediacodec      MediaCodec HEVC encoder\n';
    engine = engineOver(ffmpeg: ffmpeg, paths: paths);
    source = '${paths.videos}Profiles/My Trip/2026-09-28.mp4';
  });

  test('runs the convert command with the format\'s encoder into an out '
      'folder of scratch, reads the output once, and reports the format\'s '
      'facts', () async {
    ffmpeg.otherProbeOutput = 'audio\n';
    ffmpeg.otherKeyframeOutput = keyframePackets;

    final RenderedClip clip = await engine.convertClip(
      sourcePath: source,
      outputFileName: '2026-09-28.mp4',
      format: ultra,
      albumLabel: 'My Trip 4K',
      durationMs: 1500,
      sourceChannels: 1,
      hasSubtitleStream: true,
    );

    expect(clip.tempPath, startsWith('${paths.scratchDir}/out-'));
    expect(clip.tempPath, endsWith('/2026-09-28.mp4'));
    expect(File(clip.tempPath).existsSync(), isTrue);
    expect(
      ffmpeg.executed.single,
      ConvertClipCommand.build(
        source: source,
        output: clip.tempPath,
        format: ultra,
        encoder: VideoEncoder.hevcMediaCodec,
        albumLabel: 'My Trip 4K',
        durationMs: 1500,
        sourceChannels: 1,
      ),
    );
    expect(ffmpeg.probed, <List<String>>[
      ProbeCommands.audioStream(clip.tempPath),
      ProbeCommands.keyframes(clip.tempPath),
    ]);
    expect(
      clip,
      RenderedClip(
        tempPath: clip.tempPath,
        durationMs: 1500,
        hasSubtitleStream: true,
        width: 3840,
        height: 2160,
        hasAudio: true,
        keyframes: const ClipKeyframes(frameCount: 4, indices: <int>[0, 2, 3]),
        fps: 60,
        channels: 2,
        pixelFormat: 'yuv420p',
        schema: ClipSchema.v2,
      ),
    );
    // Only the out folder is left: the job's own folder is gone.
    expect(
      Directory(
        paths.scratchDir,
      ).listSync().map((FileSystemEntity e) => e.path),
      <String>[File(clip.tempPath).parent.path],
    );
  });

  // A source whose audio the convert could not carry (an import without
  // a track) is reported as it is: a movie then normalises it instead of
  // joining a clip without audio, which would drop the whole movie's
  // sound.
  test('an output without an audio stream is known to have none', () async {
    final RenderedClip clip = await engine.convertClip(
      sourcePath: source,
      outputFileName: '2026-09-28.mp4',
      format: const ClipFormat.legacy(VideoOrientation.landscape),
      albumLabel: 'Default',
      durationMs: 2000,
      sourceChannels: null,
      hasSubtitleStream: false,
    );

    expect(clip.hasAudio, isFalse);
    expect(clip.schema, ClipSchema.v15);
    expect(ffmpeg.executed.single, contains('libx264'));
  });

  test('a failed convert throws VideoProcessingException and leaves nothing '
      'in scratch', () async {
    ffmpeg.executeResults.add(
      FakeFfmpegGateway.failure(returnCode: 1, logs: 'Invalid data found'),
    );

    await expectLater(
      engine.convertClip(
        sourcePath: source,
        outputFileName: '2026-09-28.mp4',
        format: ultra,
        albumLabel: 'My Trip 4K',
        durationMs: 1500,
        sourceChannels: 1,
        hasSubtitleStream: false,
      ),
      throwsA(
        isA<VideoProcessingException>().having(
          (VideoProcessingException e) => e.logTail,
          'logTail',
          'Invalid data found',
        ),
      ),
    );
    expect(Directory(paths.scratchDir).listSync(recursive: true), isEmpty);
  });
}
