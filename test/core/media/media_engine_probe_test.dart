import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/commands/probe_commands.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

import '../../support/support.dart';
import '../../support/track_1a/media_engine_harness.dart';
import '../../support/track_1a/scripted_ffmpeg_gateway.dart';

const String taggedClip = '''
{"streams": [
  {"codec_type": "video", "codec_name": "h264", "width": 1080, "height": 1920,
   "r_frame_rate": "30/1"},
  {"codec_type": "audio", "codec_name": "aac"}
 ],
 "format": {"duration": "2.000000",
  "tags": {"artist": "One Second Diary (v1.5)", "album": "Work",
           "comment": "origin=gallery"}}}
''';

void main() {
  late AppPaths paths;
  late ScriptedFfmpegGateway ffmpeg;
  late MediaEngine engine;
  late String clip;

  setUp(() async {
    paths = await createTestPaths();
    ffmpeg = ScriptedFfmpegGateway();
    engine = engineOver(ffmpeg: ffmpeg, paths: paths);
    clip = '${paths.videos}Profiles/Work/2024-01-05.mp4';
  });

  test('reads streams, duration and tags with one JSON probe', () async {
    ffmpeg.probeOutputs[clip] = taggedClip;

    final ClipProbe probe = await engine.probe(clip);

    expect(ffmpeg.probed, <List<String>>[ProbeCommands.streams(clip)]);
    expect(
      probe,
      const ClipProbe(
        durationMs: 2000,
        hasAudio: true,
        hasSubtitleStream: false,
        artist: 'One Second Diary (v1.5)',
        album: 'Work',
        comment: 'origin=gallery',
        locationTag: null,
        title: null,
        width: 1080,
        height: 1920,
        codec: 'h264',
        fps: 30,
      ),
    );
  });

  // Output that is not ffprobe JSON has no return code and a
  // FormatException as its cause.
  test('a failed probe, or output that is not ffprobe JSON, is a '
      'VideoProcessingException', () async {
    ffmpeg.probeResults.add(FakeFfmpegGateway.failure(returnCode: 1));
    await expectLater(
      engine.probe(clip),
      throwsA(
        isA<VideoProcessingException>().having(
          (VideoProcessingException e) => e.returnCode,
          'returnCode',
          1,
        ),
      ),
    );

    ffmpeg.probeOutputs[clip] = 'moov atom not found';
    await expectLater(
      engine.probe(clip),
      throwsA(
        isA<VideoProcessingException>()
            .having(
              (VideoProcessingException e) => e.returnCode,
              'code',
              isNull,
            )
            .having(
              (VideoProcessingException e) => e.cause,
              'cause',
              isFormatException,
            ),
      ),
    );
  });

  // A user's job waits for at most the one background probe in flight; here
  // the probe waits for the running save.
  test('a probe is a queued job: it waits for the running save', () async {
    ffmpeg
      ..holdExecutions = true
      ..probeOutputs[clip] = taggedClip;
    final Future<void> saving = engine.remuxSubtitles(
      clipPath: clip,
      text: 'Hi',
      durationMs: 2000,
    );
    while (ffmpeg.heldSessions.isEmpty) {
      await pumpEventQueue();
    }

    final Future<ClipProbe> probing = engine.probe(clip);
    await pumpEventQueue();
    expect(ffmpeg.probed, isEmpty);

    ffmpeg.releaseHeld();
    await saving;
    await probing;
    expect(ffmpeg.probed, <List<String>>[ProbeCommands.streams(clip)]);
  });
}
