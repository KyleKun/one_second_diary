import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/launch/post_frame_launch.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/logging/log_session.dart';
import 'package:one_second_diary/core/migrations/legacy_folder_migration.dart';
import 'package:one_second_diary/core/migrations/legacy_migration_event.dart';
import 'package:one_second_diary/core/migrations/legacy_migration_report.dart';
import 'package:one_second_diary/core/migrations/orphan_sweep.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/platform/file_log_sink.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/legacy_prefs_mirror.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/onboarding/data/onboarding_store.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/fakes/fake_clip_caches.dart';
import '../../shared/fakes/fake_clip_repository.dart';
import '../../shared/fakes/fake_profiles_repository.dart';
import '../../shared/harness/fake_gateways.dart';
import '../../support/support.dart';
import '../support/journaling_fakes.dart';

const ProfileKey work = ProfileKey('Work');

void main() {
  late List<String> journal;
  late AppPaths paths;
  late FakeClock clock;
  late MemoryLogSink sink;
  late AppLogger logger;
  late FakeGateways gateways;
  late FakeProfilesRepository profiles;
  late FakeClipRepository clips;
  late List<LegacyMigrationEvent> migrationEvents;

  setUp(() async {
    journal = <String>[];
    paths = AppPaths.forTest(await createTempRoot());
    clock = FakeClock(DateTime(2024, 1, 5, 10));
    sink = MemoryLogSink();
    logger = memoryLogger(sink, clock: clock);
    gateways = FakeGateways(clock: clock, calls: journal);
    profiles = FakeProfilesRepository(
      profiles: <Profile>[
        testProfile(),
        testProfile(key: work),
      ],
      active: work,
    );
    clips = FakeClipRepository(journal: journal);
    migrationEvents = <LegacyMigrationEvent>[];
    addTearDown(() async {
      await gateways.close();
      await profiles.close();
      await clips.close();
    });
  });

  /// The launch over real prefs, log session, mirror, migration and sweep
  /// in a temp folder, and journaling fakes for the rest. [prefs] seeds the
  /// store (an onboarded install by default).
  Future<PostFrameLaunch> launch({
    Map<String, Object>? prefs,
    bool isAndroid = true,
    bool withLogFile = true,
    MediaPublisher? launchPublisher,
  }) async {
    SharedPreferences.setMockInitialValues(prefs ?? legacyPrefs());
    final JournalingPrefsStore store = JournalingPrefsStore(
      preferences: await SharedPreferences.getInstance(),
      journal: journal,
    );
    final LogSession logSession = LogSession(
      paths: paths,
      prefs: store,
      clock: clock,
    );
    final FileLogSink file = await logSession.open();
    addTearDown(file.close);
    final LegacyPrefsMirror mirror = LegacyPrefsMirror(prefs: store);
    return PostFrameLaunch(
      logSession: withLogFile ? logSession : null,
      mirror: mirror,
      paths: paths,
      deviceInfo: gateways.deviceInfo,
      appInfo: gateways.appInfo,
      permissions: PermissionRequester(
        permissions: gateways.permissions,
        deviceInfo: gateways.deviceInfo,
        logger: logger,
      ),
      isAndroid: isAndroid,
      onboarding: OnboardingStore(
        prefs: store,
        profiles: profiles,
        mirror: mirror,
        paths: paths,
        logger: logger,
      ),
      migration: LegacyFolderMigration(
        paths: paths,
        mediaStore: JournalingMediaStore.onDisk(paths, journal: journal),
        wakelock: gateways.wakelock,
        profiles: profiles,
        logger: logger,
        isAndroid: isAndroid,
      ),
      launchPublisher:
          launchPublisher ??
          JournalingMediaPublisher(paths: paths, journal: journal),
      sweep: OrphanSweep(paths: paths, clock: clock, logger: logger),
      mediaGate: JournalingMediaStartGate(journal: journal),
      engine: JournalingMediaEngine(paths: paths, journal: journal),
      reminderPlan: JournalingReminderPlan(journal: journal),
      library: JournalingLibrary(journal: journal),
      counters: JournalingCounters(journal: journal),
      metadata: FakeClipMetadataCache(journal: journal),
      thumbnails: FakeThumbnailRepository(journal: journal),
      clips: clips,
      profiles: profiles,
      logger: logger,
    );
  }

  Future<void> run(PostFrameLaunch launch) => launch.run(
    onMigrationEvent: migrationEvents.add,
    onMigrationFailed: () => journal.add('migration failed'),
  );

  /// A clip in the pre-2023 Android folder.
  Future<void> seedLegacyClip() async {
    final File clip = File('${paths.legacyAndroidVideos}2021-01-01.mp4');
    await clip.parent.create(recursive: true);
    await clip.writeAsBytes(fakeVideoBytes);
  }

  /// What a killed media job left in the scratch folder.
  Future<void> seedScratchOrphan() async {
    final File orphan = File('${paths.scratchDir}/job-1/left.mp4');
    await orphan.parent.create(recursive: true);
    await orphan.writeAsBytes(fakeVideoBytes);
  }

  test('runs the launch steps in order (SUMMARY "Handed to Phase 2" '
      '§1)', () async {
    await seedLegacyClip();
    await seedScratchOrphan();

    await run(await launch());

    expect(journal, <String>[
      // 1. What a downgrade needs, written after the first frame.
      'prefs.currentLogFile',
      'prefs.internalDirectoryPath',
      'prefs.appPath',
      'prefs.moviesPath',
      'deviceInfo.androidSdkInt',
      'prefs.sdkVersion',
      // Access to the videos: checked, then asked for.
      'deviceInfo.androidSdkInt',
      'deviceInfo.androidSdkInt',
      // 2. The folder migration.
      'wakelock.enable',
      'mediaStore.publish',
      'wakelock.disable',
      // 3. and 4. The trash, then the sweep of what killed jobs left.
      'publisher.purgeTrash (scratch full)',
      // 5. Only then media jobs and the engine, which empties the scratch
      // folder.
      'mediaGate.open',
      'engine.init (scratch empty)',
      // 6. Notifications, then the reminders.
      'reminderPlan.start',
      // 7. The caches, then the clips.
      'metadata.load',
      'thumbnails.load',
      'library.start',
      'counters.start',
      'clips.loadAll',
    ]);
  });

  // Once the videos folder exists, a denied storage permission reads as a
  // reinstall and the orientation step is skipped.
  test('never creates the diary folders before onboarding', () async {
    await run(await launch(prefs: freshInstallPrefs));

    expect(Directory(paths.videos).existsSync(), isFalse);
    expect(Directory(paths.movies).existsSync(), isFalse);
  });

  test(
    'creates the diary folders for an onboarded user, as v1.7 did',
    () async {
      await run(await launch());

      expect(Directory(paths.videos).existsSync(), isTrue);
      expect(Directory(paths.movies).existsSync(), isTrue);
    },
  );

  group('legacy folder migration', () {
    test('reports its progress and outcome for the dialog', () async {
      await seedLegacyClip();

      await run(await launch());

      expect(migrationEvents, const <LegacyMigrationEvent>[
        LegacyMigrationProgress(done: 0, total: 1),
        LegacyMigrationProgress(done: 1, total: 1),
        LegacyMigrationFinished(
          LegacyMigrationReport(
            clipsMigrated: 1,
            failed: <String>[],
            moviesMigrated: 0,
            oldFoldersRemoved: true,
          ),
        ),
      ]);
    });

    test('shows nothing when there is nothing to move', () async {
      await run(await launch());

      expect(migrationEvents, isEmpty);
      expect(journal, isNot(contains('wakelock.enable')));
    });

    test('is not needed on iOS', () async {
      await seedLegacyClip();

      await run(await launch(isAndroid: false));

      expect(migrationEvents, isEmpty);
    });

    // Before onboarding, the folders can't be read without the storage
    // permission anyway.
    test('never before onboarding', () async {
      await seedLegacyClip();

      await run(await launch(prefs: freshInstallPrefs));

      expect(migrationEvents, isEmpty);
      expect(Directory(paths.legacyAndroidVideos).listSync(), isNotEmpty);
    });

    // Its staging folder can't be made: the run ends with an error.
    test('that fails is reported, and the launch goes on', () async {
      await seedLegacyClip();
      final File blocker = File('${paths.scratchDir}/legacy_migration');
      await blocker.parent.create(recursive: true);
      await blocker.writeAsString('not a folder');

      await run(await launch());

      expect(journal, contains('migration failed'));
      expect(journal.last, 'clips.loadAll');
    });
  });

  // Without access to the gallery an Android diary can't list or save its
  // clips, so an onboarded one asks again on each launch until it is granted,
  // before the folders and the clips are read.
  group('access to the videos (Android)', () {
    test('missing: asked once, before the clips are read; a refusal is '
        'logged as v1.7 logged it, and the launch goes on', () async {
      gateways.permissions
        ..answers[AppPermission.photos] = AppPermissionStatus.denied
        ..answers[AppPermission.videos] = AppPermissionStatus.denied;

      await run(await launch());

      expect(gateways.permissions.requestedTogether, <Set<AppPermission>>[
        <AppPermission>{AppPermission.photos, AppPermission.videos},
      ]);
      expect(
        sink.lines,
        contains(
          contains(
            'Some storage permissions were not granted for sdk version '
            '34',
          ),
        ),
      );
      expect(journal.last, 'clips.loadAll');
    });

    test('granted: nothing is asked', () async {
      gateways.permissions
        ..statuses[AppPermission.photos] = AppPermissionStatus.granted
        ..statuses[AppPermission.videos] = AppPermissionStatus.granted;

      await run(await launch());

      expect(gateways.permissions.requestedTogether, isEmpty);
    });

    test('never before onboarding (O4 asks), nor on iOS', () async {
      await run(await launch(prefs: freshInstallPrefs));
      await run(await launch(isAndroid: false));

      expect(gateways.permissions.requestedTogether, isEmpty);
    });
  });

  test('deletes the session logs older than 7 days', () async {
    final PostFrameLaunch postFrame = await launch();
    final File old = File('${paths.logsDir}/2023-12-28_09-00-00.txt');
    final File kept = File('${paths.logsDir}/2023-12-29_09-00-00.txt');
    await old.writeAsString('old');
    await kept.writeAsString('kept');

    await run(postFrame);

    expect(old.existsSync(), isFalse);
    expect(kept.existsSync(), isTrue);
  });

  test("loads every profile's clips, the active one first", () async {
    await run(await launch());

    expect(clips.loads.single.active, work);
    expect(clips.loads.single.profiles, <ProfileKey>[
      ProfileKey.defaultProfile,
      work,
    ]);
  });

  test('without a log file, records no file name', () async {
    await run(await launch(withLogFile: false));

    expect(journal, isNot(contains('prefs.currentLogFile')));
    expect(journal, contains('prefs.appPath'));
  });

  test('logs a step that fails and goes on with the next', () async {
    await run(await launch(launchPublisher: _FailingPublisher()));

    expect(
      sink.lines,
      contains(
        startsWith(
          '[ERROR] 2024-01-05 10:00:00.000: [APP] Launch step failed: purge '
          'the trash',
        ),
      ),
    );
    expect(journal.last, 'clips.loadAll');
  });
}

class _FailingPublisher extends Fake implements MediaPublisher {
  @override
  Future<void> purgeTrash() async => throw const FileSystemException('EIO');
}
