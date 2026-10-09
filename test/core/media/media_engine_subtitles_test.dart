import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/commands/subtitle_commands.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/policy/srt_codec.dart';
import 'package:one_second_diary/core/platform/ffmpeg_result.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../support/support.dart';
import '../../support/track_1a/media_engine_harness.dart';
import '../../support/track_1a/scripted_ffmpeg_gateway.dart';

void main() {
  late AppPaths paths;
  late ScriptedFfmpegGateway ffmpeg;
  late MediaEngine engine;
  late File clip;

  setUp(() async {
    paths = await createTestPaths();
    ffmpeg = ScriptedFfmpegGateway();
    engine = engineOver(ffmpeg: ffmpeg, paths: paths);
    clip = await seedClip(
      paths,
      const ProfileKey('Work'),
      LocalDay(2024, 1, 5),
      ordinal: 2,
    );
  });

  group('remuxSubtitles', () {
    // The remux goes to private scratch under the clip's own file name
    // (Android publishes under the temp file's name); the original is left
    // for MediaPublisher to replace safely.
    test('copies the clip into scratch under its own name with the text as '
        'its only cue', () async {
      String? srt;
      ffmpeg.onExecute = (List<String> argv) async {
        srt = File(argv[3]).readAsStringSync();
        await ffmpeg.writeOutput(argv);
      };

      final String remuxed = await engine.remuxSubtitles(
        clipPath: clip.path,
        text: 'Lunch with Ana',
        durationMs: 1533,
      );

      final List<String> argv = ffmpeg.executed.single;
      expect(
        argv,
        SubtitleCommands.remux(
          clip: clip.path,
          subtitles: argv[3],
          output: remuxed,
        ),
      );
      expect(argv[3], startsWith('${paths.scratchDir}/'));
      expect(srt, SrtCodec.encode('Lunch with Ana', startMs: 0, endMs: 1533));
      expect(remuxed, startsWith('${paths.scratchDir}/'));
      expect(remuxed.split('/').last, '2024-01-05-2.mp4');
      expect(File(remuxed).existsSync(), isTrue);
      expect(clip.readAsBytesSync(), fakeVideoBytes, reason: 'not touched');
      expect(File(argv[3]).existsSync(), isFalse, reason: 'job folder gone');
    });

    test('empty text copies the clip without a subtitle stream', () async {
      final String remuxed = await engine.remuxSubtitles(
        clipPath: clip.path,
        text: '',
        durationMs: 1533,
      );

      expect(ffmpeg.executed, <List<String>>[
        SubtitleCommands.remove(clip: clip.path, output: remuxed),
      ]);
      expect(remuxed.split('/').last, '2024-01-05-2.mp4');
    });

    test('a failed remux throws and leaves nothing in scratch', () async {
      ffmpeg.executeResults.add(FakeFfmpegGateway.failure());

      await expectLater(
        engine.remuxSubtitles(clipPath: clip.path, text: 'Hi', durationMs: 900),
        throwsA(isA<VideoProcessingException>()),
      );
      expect(Directory(paths.scratchDir).listSync(recursive: true), isEmpty);
      expect(clip.readAsBytesSync(), fakeVideoBytes);
    });

    // A zero-length cue never shows: the text would be lost.
    test(
      'text over a clip of no length is a caller error, before any work',
      () async {
        await expectLater(
          engine.remuxSubtitles(clipPath: clip.path, text: 'Hi', durationMs: 0),
          throwsArgumentError,
        );
        expect(ffmpeg.executed, isEmpty);
      },
    );
  });

  group('readSubtitles', () {
    /// ffmpeg writes the extracted mov_text stream as SRT with LF endings.
    void extractAs(String srt) => ffmpeg.onExecute = (List<String> argv) async {
      File(ScriptedFfmpegGateway.outputOf(argv)!).writeAsStringSync(srt);
    };

    // Two reads extracting to a shared path would race.
    test('extracts the subtitle stream to its own scratch file and decodes '
        'it, a cue that ends after one minute included', () async {
      extractAs('1\n00:00:00,000 --> 00:01:05,250\nLunch with Ana \n\n');

      final String text = await engine.readSubtitles(clip.path);

      final List<String> argv = ffmpeg.executed.single;
      final String srt = ScriptedFfmpegGateway.outputOf(argv)!;
      expect(argv, SubtitleCommands.extract(clip: clip.path, output: srt));
      expect(srt, startsWith('${paths.scratchDir}/'));
      expect(srt, endsWith('.srt'));
      expect(text, 'Lunch with Ana');
      expect(File(srt).existsSync(), isFalse, reason: 'job folder deleted');
    });

    // The .srt output makes ffmpeg pick only the subtitle stream, so a clip
    // without one FAILS: that failure means "no subtitles". A subtitle file
    // that is not UTF-8 never throws.
    test('a clip without a subtitle stream, or with an unreadable one, reads '
        'as no text', () async {
      ffmpeg.executeResults.add(
        FakeFfmpegGateway.failure(
          logs: 'Output file does not contain any stream',
        ),
      );
      expect(await engine.readSubtitles(clip.path), '');

      ffmpeg.onExecute = (List<String> argv) async {
        File(
          ScriptedFfmpegGateway.outputOf(argv)!,
        ).writeAsBytesSync(<int>[0x31, 0x0A, 0xFF, 0xFE, 0x0A]);
      };
      expect(await engine.readSubtitles(clip.path), '');
    });

    // No return code means the plugin failed (a PlatformException while
    // starting or reading the session), not that ffmpeg found no stream.
    // Read as '', the backfill would cache "no text" for a clip it probed
    // WITH a subtitle stream until the file changes. A session stopped from
    // outside (return code 255) did not look for the stream either: a
    // cancellation, as for every other job.
    test('a plugin error or a cancelled session throws instead of reading '
        'as no text', () async {
      ffmpeg.executeResults.add(
        const FfmpegResult(
          returnCode: null,
          output: '',
          logs: 'ffmpeg-kit error: PlatformException(channel closed)',
          failStackTrace: null,
        ),
      );
      await expectLater(
        engine.readSubtitles(clip.path),
        throwsA(
          isA<VideoProcessingException>()
              .having((e) => e.returnCode, 'returnCode', isNull)
              .having((e) => e.logTail, 'logTail', contains('channel closed')),
        ),
      );

      ffmpeg.executeResults.add(FakeFfmpegGateway.cancelledResult());
      await expectLater(
        engine.readSubtitles(clip.path),
        throwsA(isA<CancelledException>()),
      );
    });
  });
}
