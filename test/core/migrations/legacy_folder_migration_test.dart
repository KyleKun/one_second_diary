import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/migrations/legacy_folder_migration.dart';
import 'package:one_second_diary/core/migrations/legacy_migration_event.dart';
import 'package:one_second_diary/core/migrations/legacy_migration_report.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../support/support.dart';
import '../../support/track_1c/read_only_folder.dart';
import '../../support/track_1c/refusing_media_store_gateway.dart';
import '../../support/track_1c/refusing_shared_preferences.dart';

void main() {
  late AppPaths paths;
  late MemoryLogSink log;
  late FakeMediaStoreGateway mediaStore;
  late FakeWakelockGateway wakelock;
  late PrefsStore prefs;

  setUp(() async {
    paths = await createTestPaths();
    log = MemoryLogSink();
    mediaStore = FakeMediaStoreGateway.onDisk(paths);
    wakelock = FakeWakelockGateway();
    prefs = await openLegacyPrefs(legacyPrefs());
  });

  LegacyFolderMigration migration({bool isAndroid = true}) =>
      LegacyFolderMigration(
        paths: paths,
        mediaStore: mediaStore,
        wakelock: wakelock,
        profiles: ProfilesRepository(
          prefs: prefs,
          paths: paths,
          mediaStore: mediaStore,
          clock: FakeClock(DateTime(2024, 1, 5)),
          logger: memoryLogger(log),
          defaultLabel: () => 'Default',
        ),
        logger: memoryLogger(log),
        isAndroid: isAndroid,
      );

  /// Writes a movie in the pre-2023 movies folder.
  Future<File> seedOldMovie(String name) async {
    final File file = File('${paths.legacyAndroidMovies}$name');
    await file.parent.create(recursive: true);
    return file.writeAsBytes(fakeVideoBytes);
  }

  /// Writes a file in the pre-2023 folder, at [relative] to it.
  Future<File> seedOld(
    String relative, {
    List<int> bytes = fakeVideoBytes,
  }) async {
    final File file = File('${paths.legacyAndroidVideos}$relative');
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes);
  }

  test(
    'nothing runs on iOS, even with an old-looking folder (I CL-08 d)',
    () async {
      final File old = await seedOld('2021-01-01.mp4');
      final LegacyFolderMigration ios = migration(isAndroid: false);

      expect(await ios.isNeeded(), isFalse);
      final List<LegacyMigrationEvent> events = await ios.run().toList();

      expect(events, hasLength(1));
      expect(events.single, isA<LegacyMigrationFinished>());
      expect(await old.exists(), isTrue);
      expect(mediaStore.calls, isEmpty);
    },
  );

  test('moves every old clip into the diary folder through the media store, '
      'then removes the old folder', () async {
    await seedOld('2021-01-01.mp4', bytes: <int>[1]);
    await seedOld('2021-01-02.mp4', bytes: <int>[2]);
    final LegacyFolderMigration android = migration();
    expect(await android.isNeeded(), isTrue);

    final List<LegacyMigrationEvent> events = await android.run().toList();

    expect(
      events.last,
      const LegacyMigrationFinished(
        LegacyMigrationReport(
          clipsMigrated: 2,
          failed: <String>[],
          moviesMigrated: 0,
          oldFoldersRemoved: true,
        ),
      ),
    );
    expect(await File('${paths.videos}2021-01-01.mp4').readAsBytes(), <int>[1]);
    expect(await File('${paths.videos}2021-01-02.mp4').readAsBytes(), <int>[2]);
    expect(
      mediaStore.calls.whereType<PublishCall>().map((PublishCall c) => c.album),
      <String>['OneSecondDiary', 'OneSecondDiary'],
    );
    expect(await Directory(paths.legacyAndroidVideos).exists(), isFalse);
    expect(await android.isNeeded(), isFalse);
  });

  test('a clip the media store refuses keeps its original and the old '
      'folder, and the movies wait (I CL-08 a)', () async {
    await seedOld('2021-01-01.mp4');
    final File refused = await seedOld('2021-01-02.mp4');
    final File movie = await seedOldMovie('OneSecondDiary-Movie-1-2021.mp4');
    mediaStore = RefusingMediaStoreGateway.onDisk(
      paths,
      refusedPublishes: <String>{'2021-01-02.mp4'},
    );

    final List<LegacyMigrationEvent> events = await migration().run().toList();

    expect(
      events.last,
      const LegacyMigrationFinished(
        LegacyMigrationReport(
          clipsMigrated: 1,
          failed: <String>['OneSecondDiary/2021-01-02.mp4'],
          moviesMigrated: 0,
          oldFoldersRemoved: false,
        ),
      ),
    );
    expect(await refused.exists(), isTrue);
    expect(await File('${paths.videos}2021-01-01.mp4').exists(), isTrue);
    expect(
      await File('${paths.legacyAndroidVideos}2021-01-01.mp4').exists(),
      isFalse,
    );
    expect(await movie.exists(), isTrue);
    expect(
      await Directory('${paths.scratchDir}/legacy_migration').exists(),
      isFalse,
      reason: 'no staged copy is left behind',
    );
    expect(
      log.lines,
      contains(allOf(startsWith('[WARNING]'), contains('2021-01-02.mp4'))),
    );
  });

  test(
    'a run after a partial one moves only what is left (I CL-08 b)',
    () async {
      await seedOld('2021-01-01.mp4');
      await seedOld('2021-01-02.mp4');
      mediaStore = RefusingMediaStoreGateway.onDisk(
        paths,
        refusedPublishes: <String>{'2021-01-02.mp4'},
      );
      await migration().run().drain<void>();
      mediaStore = FakeMediaStoreGateway.onDisk(paths);

      final List<LegacyMigrationEvent> events = await migration()
          .run()
          .toList();

      expect(
        mediaStore.calls.whereType<PublishCall>().map(
          (PublishCall c) => c.tempFilePath.split('/').last,
        ),
        <String>['2021-01-02.mp4'],
      );
      expect(
        (events.last as LegacyMigrationFinished).report,
        const LegacyMigrationReport(
          clipsMigrated: 1,
          failed: <String>[],
          moviesMigrated: 0,
          oldFoldersRemoved: true,
        ),
      );
    },
  );

  test('a clip already at its destination with the same size was moved by a '
      'run that stopped before deleting the original: the original goes; a '
      'different file there is never replaced, and is reported once', () async {
    await seedOld('2021-01-01.mp4', bytes: <int>[1, 1]);
    await seedOld('2021-01-02.mp4', bytes: <int>[2, 2]);
    await seedOld('2021-01-03.mp4', bytes: <int>[3, 3]);
    await seedClip(
      paths,
      ProfileKey.defaultProfile,
      LocalDay(2021, 1, 1),
      bytes: <int>[1, 1],
    );
    final File newer = await seedClip(
      paths,
      ProfileKey.defaultProfile,
      LocalDay(2021, 1, 2),
      bytes: <int>[9, 9, 9],
    );

    final List<LegacyMigrationEvent> events = await migration().run().toList();

    expect(mediaStore.calls, hasLength(1), reason: 'only 2021-01-03');
    expect(await newer.readAsBytes(), <int>[9, 9, 9]);
    expect(
      await File('${paths.legacyAndroidVideos}2021-01-01.mp4').exists(),
      isFalse,
    );
    expect(
      await File('${paths.legacyAndroidVideos}2021-01-02.mp4').readAsBytes(),
      <int>[2, 2],
    );
    expect(
      (events.last as LegacyMigrationFinished).report,
      const LegacyMigrationReport(
        clipsMigrated: 2,
        failed: <String>['OneSecondDiary/2021-01-02.mp4'],
        moviesMigrated: 0,
        oldFoldersRemoved: false,
      ),
    );
    expect(
      await migration().isNeeded(),
      isFalse,
      reason: 'reported once; no blocking dialog at every launch',
    );
  });

  test('an old folder it can\'t list (no storage access) is left alone, as '
      'if absent, instead of failing behind the dialog', () async {
    await seedOld('2021-01-01.mp4');
    Process.runSync('chmod', <String>['000', paths.legacyAndroidVideos]);
    addTearDown(
      () =>
          Process.runSync('chmod', <String>['755', paths.legacyAndroidVideos]),
    );
    try {
      Directory(paths.legacyAndroidVideos).listSync();
      markTestSkipped('this user can list any folder (root)');
      return;
    } on FileSystemException {
      // Unlistable, as on the phone.
    }

    expect(await migration().isNeeded(), isFalse);
    expect(await migration().run().toList(), <LegacyMigrationEvent>[
      const LegacyMigrationFinished(LegacyMigrationReport.nothingToDo),
    ]);
  });

  test('originals it can\'t delete (a previous install made them, Android '
      '11+) are reported once: with every clip in the diary, it is no longer '
      'needed, so no blocking dialog at every launch', () async {
    await seedOld('2021-01-01.mp4');
    final LegacyFolderMigration android = migration();
    if (!makeReadOnly(paths.legacyAndroidVideos)) {
      markTestSkipped('This user can unlink in a mode-555 folder (root?).');
      return;
    }

    final List<LegacyMigrationEvent> first = await android.run().toList();

    expect(
      (first.last as LegacyMigrationFinished).report,
      const LegacyMigrationReport(
        clipsMigrated: 1,
        failed: <String>[],
        moviesMigrated: 0,
        oldFoldersRemoved: false,
      ),
      reason: "v1.7's migrationFolderDeletionError, once",
    );
    expect(await android.isNeeded(), isFalse);
    expect(await android.run().toList(), <LegacyMigrationEvent>[
      const LegacyMigrationFinished(LegacyMigrationReport.nothingToDo),
    ]);
    expect(await File('${paths.videos}2021-01-01.mp4').exists(), isTrue);
  });

  test('counts only the clips this run moved: one already in the diary whose '
      'original it can\'t delete changed nothing', () async {
    await seedOld('2021-01-01.mp4', bytes: <int>[1, 1]);
    await seedOld('2021-01-02.mp4', bytes: <int>[2, 2]);
    await seedClip(
      paths,
      ProfileKey.defaultProfile,
      LocalDay(2021, 1, 1),
      bytes: <int>[1, 1],
    );
    if (!makeReadOnly(paths.legacyAndroidVideos)) {
      markTestSkipped('This user can unlink in a mode-555 folder (root?).');
      return;
    }

    final List<LegacyMigrationEvent> events = await migration().run().toList();

    expect(
      (events.last as LegacyMigrationFinished).report,
      const LegacyMigrationReport(
        clipsMigrated: 1,
        failed: <String>[],
        moviesMigrated: 0,
        oldFoldersRemoved: false,
      ),
    );
    expect(await File('${paths.videos}2021-01-02.mp4').readAsBytes(), <int>[
      2,
      2,
    ]);
  });

  test('a clip under Profiles/<name>/ goes to that profile\'s album and '
      'registers the profile, landscape and not active (I CL-08 c)', () async {
    await seedOld('Profiles/Kids/2021-01-01.mp4');
    await seedOld('trip/2021-01-03.mp4');

    await migration().run().drain<void>();

    expect(
      mediaStore.calls.whereType<PublishCall>().map((PublishCall c) => c.album),
      unorderedEquals(<String>[
        'OneSecondDiary/Profiles/Kids',
        'OneSecondDiary/trip',
      ]),
    );
    expect(
      await File(
        '${paths.profileVideos(const ProfileKey('Kids'))}2021-01-01.mp4',
      ).exists(),
      isTrue,
    );
    // A user-made sub-folder keeps its place: flattened into the root, two
    // same-named clips would replace each other.
    expect(await File('${paths.videos}trip/2021-01-03.mp4').exists(), isTrue);
    expect(prefs.read(PrefKeys.profiles), <String>['Default', 'Kids']);
    expect(
      prefs.contains(PrefKeys.orientation(const ProfileKey('Kids'))),
      isFalse,
    );
    expect(prefs.read(PrefKeys.selectedProfileIndex), 0);
  });

  test('once every clip moved, the old movies go to Movies/ and both old '
      'folders are removed (a6e13a6: the movies folder is optional); movies '
      'left after an earlier run still move', () async {
    await seedOld('2021-01-01.mp4');
    await seedOldMovie('OneSecondDiary-Movie-1-2021-01-01.mp4');

    final List<LegacyMigrationEvent> events = await migration().run().toList();

    expect(
      (events.last as LegacyMigrationFinished).report,
      const LegacyMigrationReport(
        clipsMigrated: 1,
        failed: <String>[],
        moviesMigrated: 1,
        oldFoldersRemoved: true,
      ),
    );
    expect(
      mediaStore.calls.whereType<PublishCall>().last.album,
      'OneSecondDiary/Movies',
    );
    expect(
      await File(
        '${paths.movies}OneSecondDiary-Movie-1-2021-01-01.mp4',
      ).exists(),
      isTrue,
    );
    expect(await Directory(paths.legacyAndroidMovies).exists(), isFalse);
    expect(await Directory(paths.legacyAndroidVideos).exists(), isFalse);

    // Old movies left after an earlier run still move, without the old
    // clips folder.
    await seedOldMovie('OneSecondDiary-Movie-2-2021-02-01.mp4');
    final LegacyFolderMigration android = migration();

    expect(await android.isNeeded(), isTrue);
    await android.run().drain<void>();

    expect(
      await File(
        '${paths.movies}OneSecondDiary-Movie-2-2021-02-01.mp4',
      ).exists(),
      isTrue,
    );
    expect(await android.isNeeded(), isFalse);
  });

  test(
    'a movie the media store refuses stays in OSD-Movies/ and is '
    'reported; the old clips folder, fully moved, is still removed',
    () async {
      await seedOld('2021-01-01.mp4');
      final File movie = await seedOldMovie('OneSecondDiary-Movie-1-2021.mp4');
      mediaStore = RefusingMediaStoreGateway.onDisk(
        paths,
        refusedPublishes: <String>{'OneSecondDiary-Movie-1-2021.mp4'},
      );
      final LegacyFolderMigration android = migration();

      final List<LegacyMigrationEvent> events = await android.run().toList();

      expect(
        (events.last as LegacyMigrationFinished).report,
        const LegacyMigrationReport(
          clipsMigrated: 1,
          failed: <String>['OSD-Movies/OneSecondDiary-Movie-1-2021.mp4'],
          moviesMigrated: 0,
          oldFoldersRemoved: false,
        ),
      );
      expect(await movie.exists(), isTrue);
      expect(await Directory(paths.legacyAndroidVideos).exists(), isFalse);
      expect(await android.isNeeded(), isTrue, reason: 'retried next launch');
    },
  );

  test(
    'holds the wakelock while files move and reports progress per file',
    () async {
      await seedOld('2021-01-01.mp4');
      await seedOld('2021-01-02.mp4');
      await seedOldMovie('OneSecondDiary-Movie-1-2021.mp4');
      final List<(int, int, bool)> seen = <(int, int, bool)>[];

      await for (final LegacyMigrationEvent event in migration().run()) {
        if (event case LegacyMigrationProgress(
          :final int done,
          :final int total,
        )) {
          seen.add((done, total, wakelock.enabled));
        }
      }

      expect(seen, <(int, int, bool)>[
        (0, 3, true),
        (1, 3, true),
        (2, 3, true),
        (3, 3, true),
      ]);
      expect(wakelock.enabled, isFalse);
    },
  );

  test(
    'ends with the error and releases the wakelock when a step fails',
    () async {
      await seedOld('2021-01-01.mp4');
      await seedOld('Profiles/Kids/2021-01-01.mp4');
      // The platform refuses to register the profile.
      final (PrefsStore refusing, _) = await openRefusingPrefs(
        legacyPrefs(),
        refused: <String>{'profiles'},
      );
      prefs = refusing;

      await expectLater(
        migration().run().drain<void>(),
        throwsA(isA<StorageException>()),
      );
      expect(wakelock.enabled, isFalse);
    },
  );

  test('the Originals folder beside the diary (DCIM/OneSecondDiary '
      'Originals, decision D29) is never an old folder: nothing is needed '
      'and nothing moves', () async {
    final File original = File(
      '${paths.originals}Profiles/Work/2024-01-05.mov',
    );
    await original.parent.create(recursive: true);
    await original.writeAsBytes(fakeVideoBytes);

    expect(await migration().isNeeded(), isFalse);
    final List<LegacyMigrationEvent> events = await migration().run().toList();

    expect(events.single, isA<LegacyMigrationFinished>());
    expect(original.existsSync(), isTrue);
    expect(mediaStore.calls, isEmpty);
  });

  test('skips the top-level Logs/ folder and v1.x movie temps, which go with '
      'the old folder, so a folder holding only those needs no migration (v1.7 '
      'stopped when nothing was left to count); any other video moves, '
      'whatever its case or folder', () async {
    await seedOld('Logs/log-2022-12-01.txt');
    await seedOld('Logs/2022-12-01.mp4');
    await seedOld('2021-01-01_123456.mp4');
    expect(await migration().isNeeded(), isFalse);

    await seedOld('notes.txt');
    await seedOld('VID_0001.MP4');
    await seedOld('Profiles/Blogs/2021-01-01.mp4');

    final List<LegacyMigrationEvent> events = await migration().run().toList();

    expect(
      mediaStore.calls.whereType<PublishCall>().map(
        (PublishCall c) => c.tempFilePath.split('/').last,
      ),
      unorderedEquals(<String>['VID_0001.MP4', '2021-01-01.mp4']),
    );
    expect(
      await File(
        '${paths.profileVideos(const ProfileKey('Blogs'))}2021-01-01.mp4',
      ).exists(),
      isTrue,
      reason: 'v1.7 dropped every path containing "Logs" and deleted it',
    );
    expect(
      (events.last as LegacyMigrationFinished).report.oldFoldersRemoved,
      isTrue,
    );
  });

  // The wakelock only keeps the screen on; a platform that refuses it must
  // not stop the move.
  test('a wakelock the platform refuses is logged and the clips still '
      'move', () async {
    final File old = await seedOld('2021-01-01.mp4');
    wakelock = _RefusingWakelockGateway();

    final List<LegacyMigrationEvent> events = await migration().run().toList();

    expect(await old.exists(), isFalse);
    expect((events.last as LegacyMigrationFinished).report.clipsMigrated, 1);
    expect(
      log.lines,
      contains(allOf(startsWith('[WARNING]'), contains('wakelock'))),
    );
  });

  // media_store_plus can answer true with the file elsewhere (a unique
  // "… (1).mp4" name from Android 10, a hard-coded DCIM copy below it).
  // Deleting the original then would leave the diary without that clip.
  test('a publish reported done whose file is not at its destination keeps '
      'the original and the old folder', () async {
    final File old = await seedOld('2021-01-01.mp4');
    mediaStore = _UniqueNamingGateway(paths);

    final List<LegacyMigrationEvent> events = await migration().run().toList();

    expect(await old.exists(), isTrue);
    expect(
      (events.last as LegacyMigrationFinished).report,
      const LegacyMigrationReport(
        clipsMigrated: 0,
        failed: <String>['OneSecondDiary/2021-01-01.mp4'],
        moviesMigrated: 0,
        oldFoldersRemoved: false,
      ),
    );
  });
}

/// Publishes like Android when the name is taken on disk but not in the
/// MediaStore: the file lands as `<name> (1).mp4` and the call says true.
class _UniqueNamingGateway extends FakeMediaStoreGateway {
  _UniqueNamingGateway(super.paths) : super.onDisk();

  @override
  Future<bool> publish({
    required String tempFilePath,
    required String album,
  }) async {
    calls.add(PublishCall(tempFilePath: tempFilePath, album: album));
    final String name = tempFilePath.substring(
      tempFilePath.lastIndexOf('/') + 1,
    );
    final Directory folder = Directory('$mediaRoot/$album');
    await folder.create(recursive: true);
    await File(
      tempFilePath,
    ).rename('${folder.path}/${name.replaceFirst('.mp4', ' (1).mp4')}');
    return true;
  }
}

/// A wakelock the platform refuses, both ways.
class _RefusingWakelockGateway extends FakeWakelockGateway {
  @override
  Future<void> enable() async =>
      throw PlatformException(code: 'error', message: 'wakelock unavailable');

  @override
  Future<void> disable() async =>
      throw PlatformException(code: 'error', message: 'wakelock unavailable');
}
