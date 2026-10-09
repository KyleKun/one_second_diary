import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/wiring/library_wiring.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/thumbnail_tier.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/fakes/clip_index_fixture.dart';
import '../../shared/fakes/fake_clip_caches.dart';
import '../../shared/fakes/fake_clip_repository.dart';
import '../../shared/fakes/fake_profiles_repository.dart';
import '../../support/support.dart';
import '../../support/track_1b/eventually.dart';

const ProfileKey work = ProfileKey('Work');

void main() {
  late AppPaths paths;
  late FakeClock clock;
  late AppLogger logger;
  late FakeProfilesRepository profiles;
  late FakeClipRepository clips;
  late FakeClipMetadataBackfill backfill;
  late FakeThumbnailRepository thumbnails;
  late ClipMetadataCache metadata;
  late MidnightTicker midnight;
  late StreamController<AppLifecycleState> lifecycle;

  setUp(() async {
    paths = await createTestPaths();
    clock = FakeClock(DateTime(2024, 1, 5, 10));
    logger = memoryLogger(MemoryLogSink(), clock: clock);
    profiles = FakeProfilesRepository();
    clips = FakeClipRepository();
    backfill = FakeClipMetadataBackfill();
    thumbnails = FakeThumbnailRepository();
    metadata = ClipMetadataCache(paths: paths, logger: logger);
    midnight = MidnightTicker(clock: clock);
    lifecycle = StreamController<AppLifecycleState>.broadcast();
    addTearDown(() async {
      await profiles.close();
      await clips.close();
      await lifecycle.close();
    });
  });

  LibraryWiring wiring() {
    final LibraryWiring wiring = LibraryWiring(
      profiles: profiles,
      clips: clips,
      backfill: backfill,
      thumbnails: thumbnails,
      metadata: metadata,
      midnight: midnight,
      lifecycleStates: lifecycle.stream,
      logger: logger,
    );
    addTearDown(wiring.dispose);
    return wiring;
  }

  group('clip snapshots', () {
    test('every snapshot of every profile, the active one first, feeds the '
        'metadata backfill and the cell thumbnails', () async {
      profiles = FakeProfilesRepository(
        profiles: <Profile>[
          testProfile(),
          testProfile(key: work, orientation: VideoOrientation.portrait),
        ],
        active: work,
      );
      final ClipIndex defaultIndex = clipIndexOf(
        ProfileKey.defaultProfile,
        <LocalDay>[LocalDay(2024, 1, 3)],
      );
      final ClipIndex workIndex = clipIndexOf(work, <LocalDay>[
        LocalDay(2024, 1, 4),
      ]);
      clips
        ..publish(defaultIndex)
        ..publish(workIndex);

      wiring().start();
      await pumpEventQueue();
      final ClipIndex later = clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[
        LocalDay(2024, 1, 3),
        LocalDay(2024, 1, 5),
      ]);
      clips.publish(later);
      await pumpEventQueue();

      expect(backfill.enqueued, <ClipIndex>[workIndex, defaultIndex, later]);
      expect(thumbnails.backfills, <ThumbnailBackfill>[
        (
          index: workIndex,
          tier: ThumbnailTier.cell,
          orientation: VideoOrientation.portrait,
        ),
        (
          index: defaultIndex,
          tier: ThumbnailTier.cell,
          orientation: VideoOrientation.landscape,
        ),
        (
          index: later,
          tier: ThumbnailTier.cell,
          orientation: VideoOrientation.landscape,
        ),
      ]);
    });

    // ClipRepository logs a failed scan and reports it on the watch stream.
    test('a profile that could not be read does not stop the wiring', () async {
      wiring().start();
      await pumpEventQueue();
      clips.fail(
        ProfileKey.defaultProfile,
        const StorageException('Could not list the clips'),
      );
      await pumpEventQueue();

      final ClipIndex index = clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[
        LocalDay(2024, 1, 5),
      ]);
      clips.publish(index);
      await pumpEventQueue();

      expect(backfill.enqueued, <ClipIndex>[index]);
    });
  });

  group('profile events', () {
    test('a new profile is scanned, and its snapshots feed the thumbnails in '
        'its canvas', () async {
      wiring().start();
      await pumpEventQueue();

      profiles.addProfile(
        testProfile(key: work, orientation: VideoOrientation.portrait),
      );
      await pumpEventQueue();
      final ClipIndex workIndex = clipIndexOf(work, <LocalDay>[
        LocalDay(2024, 1, 5),
      ]);
      clips.publish(workIndex);
      await pumpEventQueue();

      expect(clips.rescanned, <ProfileKey>[work]);
      expect(thumbnails.backfills.last, (
        index: workIndex,
        tier: ThumbnailTier.cell,
        orientation: VideoOrientation.portrait,
      ));
    });

    test('a deleted profile leaves the clip library', () async {
      profiles = FakeProfilesRepository(
        profiles: <Profile>[
          testProfile(),
          testProfile(key: work),
        ],
      );
      wiring().start();
      await pumpEventQueue();

      profiles.removeProfile(work);
      await pumpEventQueue();

      expect(clips.removed, <ProfileKey>[work]);
    });
  });

  group('app lifecycle', () {
    test('a resume rescans the changed folders for the active profile and '
        'catches up with the day', () async {
      profiles = FakeProfilesRepository(
        profiles: <Profile>[
          testProfile(),
          testProfile(key: work),
        ],
        active: work,
      );
      final List<LocalDay> days = <LocalDay>[];
      midnight.days.listen(days.add);
      wiring().start();
      await pumpEventQueue();

      clock.setNow(DateTime(2024, 1, 6, 8));
      lifecycle.add(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(clips.rescannedChangedFor, <ProfileKey>[work]);
      expect(days, <LocalDay>[LocalDay(2024, 1, 6)]);
    });

    // The backfill saves at most every 30 s; the process may not come back.
    test('a pause saves what the metadata backfill learnt', () async {
      const FileStamp stamp = FileStamp(sizeBytes: 8, modifiedMs: 0);
      wiring().start();
      metadata.put(
        relPath: '2024-01-05.mp4',
        stamp: stamp,
        meta: const ClipMeta(durationMs: 1500),
      );

      lifecycle.add(AppLifecycleState.paused);
      await eventually(
        () => File(
          '${paths.supportIndexDir}/${ClipMetadataCache.fileName}',
        ).existsSync(),
      );

      final ClipMetadataCache nextLaunch = ClipMetadataCache(
        paths: paths,
        logger: logger,
      );
      await nextLaunch.load();
      expect(
        nextLaunch.lookup(relPath: '2024-01-05.mp4', stamp: stamp),
        const ClipMeta(durationMs: 1500),
      );
    });
  });

  test('stops following everything once disposed', () async {
    final LibraryWiring subject = wiring()..start();
    await pumpEventQueue();

    await subject.dispose();
    clips.publish(
      clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[LocalDay(2024, 1, 5)]),
    );
    await pumpEventQueue();

    expect(backfill.enqueued, isEmpty);
    expect(lifecycle.hasListener, isFalse);
  });
}
