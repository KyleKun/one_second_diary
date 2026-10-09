import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/logging/log_session.dart';
import 'package:one_second_diary/core/platform/file_log_sink.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';

import '../../support/support.dart';

void main() {
  late AppPaths paths;
  late PrefsStore prefs;
  late FakeClock clock;

  setUp(() async {
    // Nothing created yet: the session is the first thing that runs.
    paths = AppPaths.forTest(await createTempRoot());
    prefs = await openLegacyPrefs(freshInstallPrefs);
    clock = FakeClock(DateTime(2024, 1, 5, 9, 3, 7, 250));
  });

  LogSession session() => LogSession(paths: paths, prefs: prefs, clock: clock);

  // The key is written after the first frame, so open() never waits for a
  // SharedPreferences commit.
  test('open creates the session file, named like v1.7, before the first '
      'line (Z MB-07); recordFileName then names it in currentLogFile, where '
      'a downgraded v1.7 appends', () async {
    final LogSession opened = session();
    final FileLogSink sink = await opened.open();
    addTearDown(sink.close);
    final AppLogger logger = AppLogger(
      sink: sink,
      clock: clock,
      isVerboseEnabled: () => false,
    );
    final File file = File('${paths.logsDir}/2024-01-05_09-03-07.txt');

    expect(await file.exists(), isTrue);
    expect(prefs.contains(PrefKeys.currentLogFile), isFalse);

    logger.info('ONBOARDING', 'intro shown');
    await logger.flush();
    expect(
      await file.readAsString(),
      '[INFO] 2024-01-05 09:03:07.250: [ONBOARDING] intro shown\n',
    );

    await opened.recordFileName();
    expect(prefs.read(PrefKeys.currentLogFile), '2024-01-05_09-03-07.txt');
  });

  test('open throws a StorageException when the file cannot be created, and '
      'leaves currentLogFile alone', () async {
    // A file where the private folder should be: nothing can go inside.
    await File(paths.internal).create(recursive: true);

    await expectLater(session().open(), throwsA(isA<StorageException>()));
    expect(prefs.contains(PrefKeys.currentLogFile), isFalse);
  });

  group('deleteOldLogs (v1.7 retention, legacy RG-13)', () {
    test('deletes and logs the session logs dated more than 7 days before '
        'today, keeps the rest, and skips a name it cannot date instead of '
        'stopping (v1.7 gave up on the first one)', () async {
      // Today is 2024-01-05.
      for (final String name in <String>[
        'notes.txt',
        '2023-12-20_08-00-00.txt',
        '2023-12-28_23-59-59.txt',
        '2023-12-29_00-00-00.txt',
        '2024-01-05_09-03-07.txt',
        // A name with "videos" in it is never deleted, whatever its date.
        '2023-12-20_videos.txt',
        // Not a session log.
        '2023-12-20_08-00-00.zip',
      ]) {
        await File('${paths.logsDir}/$name').create(recursive: true);
      }
      final MemoryLogSink sink = MemoryLogSink();

      await session().deleteOldLogs(logger: memoryLogger(sink));

      expect(
        <String>[
          await for (final FileSystemEntity entity in Directory(
            paths.logsDir,
          ).list())
            entity.uri.pathSegments.last,
        ],
        unorderedEquals(<String>[
          'notes.txt',
          '2023-12-29_00-00-00.txt',
          '2024-01-05_09-03-07.txt',
          '2023-12-20_videos.txt',
          '2023-12-20_08-00-00.zip',
        ]),
      );
      expect(
        sink.lines,
        unorderedEquals(<String>[
          '[INFO] 2024-01-05 10:00:00.000: [LOGS] Deleted old log file: '
              '2023-12-20_08-00-00.txt',
          '[INFO] 2024-01-05 10:00:00.000: [LOGS] Deleted old log file: '
              '2023-12-28_23-59-59.txt',
        ]),
      );
    });

    test(
      'never throws: a folder it cannot list is logged as a warning',
      () async {
        final MemoryLogSink sink = MemoryLogSink();

        // The logs folder does not exist.
        await session().deleteOldLogs(logger: memoryLogger(sink));

        expect(
          sink.lines.single,
          startsWith(
            '[WARNING] 2024-01-05 10:00:00.000: [LOGS] Could not delete old '
            'log files\nError: ',
          ),
        );
      },
    );
  });
}
