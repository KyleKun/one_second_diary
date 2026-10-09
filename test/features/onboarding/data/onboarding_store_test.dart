import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/legacy_prefs_mirror.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/onboarding/data/onboarding_store.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/support.dart';
import '../../../support/track_1c/refusing_shared_preferences.dart';

/// What an older install stored when onboarding completed.
const Map<String, Object> _completed = <String, Object>{
  'profiles': <String>['Default'],
  'orientation_': 'portrait',
  'videoCount': 0,
  'movieCount': 1,
  'showIntro': false,
};

void main() {
  late AppPaths paths;
  late MemoryLogSink log;

  setUp(() async {
    paths = await createTestPaths();
    log = MemoryLogSink();
  });

  OnboardingStore storeOver(PrefsStore prefs) => OnboardingStore(
    prefs: prefs,
    profiles: ProfilesRepository(
      prefs: prefs,
      paths: paths,
      mediaStore: FakeMediaStoreGateway(),
      clock: FakeClock(DateTime(2024, 1, 5)),
      logger: memoryLogger(log),
      defaultLabel: () => 'Default',
    ),
    mirror: LegacyPrefsMirror(prefs: prefs),
    paths: paths,
    logger: memoryLogger(log),
  );

  Future<OnboardingStore> storeWith(Map<String, Object> values) async =>
      storeOver(await openLegacyPrefs(values));

  test('onboarded if and only if showIntro is exactly false', () async {
    expect((await storeWith(legacyPrefs())).isOnboarded, isTrue);
    expect(
      (await storeWith(legacyPrefs(showIntro: null))).isOnboarded,
      isFalse,
    );
    expect(
      (await storeWith(legacyPrefs(showIntro: true))).isOnboarded,
      isFalse,
    );
    expect((await storeWith(freshInstallPrefs)).isOnboarded, isFalse);
  });

  group('fixed Default orientation (reinstall detection)', () {
    test('Default clips on disk fix it to landscape, so O4 is skipped (I '
        'CL-11, O1: a user-made sub-folder counts, even one called Movies); '
        'a fresh install, leftover movies, other profiles\' clips, temps and '
        'junk leave the choice open (flips Z-04, Z MB-04); without the '
        'storage permission an existing diary folder counts (scoped storage '
        'lists only this install\'s files, v1.7 storage_utils.dart:90), '
        'with a warning; an orientation stored by an interrupted onboarding '
        'is kept (Z MB-10)', () async {
      final List<
        (
          String,
          Map<String, Object>,
          bool,
          Future<void> Function(AppPaths),
          VideoOrientation?,
          bool,
        )
      >
      cases =
          <
            (
              String,
              Map<String, Object>,
              bool,
              Future<void> Function(AppPaths),
              VideoOrientation?,
              bool,
            )
          >[
            // (case, prefs, can read the gallery, the disk, fixed, warned)
            (
              'a fresh install',
              freshInstallPrefs,
              true,
              (_) async {},
              null,
              false,
            ),
            (
              'no diary folder at all',
              freshInstallPrefs,
              true,
              (AppPaths p) => Directory(p.videos).delete(recursive: true),
              null,
              false,
            ),
            (
              'a Default clip',
              freshInstallPrefs,
              true,
              (AppPaths p) =>
                  seedClip(p, ProfileKey.defaultProfile, LocalDay(2024, 1, 5)),
              VideoOrientation.landscape,
              false,
            ),
            (
              'a Default clip in a user-made sub-folder',
              freshInstallPrefs,
              true,
              (AppPaths p) => seedClip(
                p,
                ProfileKey.defaultProfile,
                LocalDay(2024, 1, 5),
                ordinal: 2,
                subFolder: 'trip/Movies',
              ),
              VideoOrientation.landscape,
              false,
            ),
            (
              'leftovers and junk',
              freshInstallPrefs,
              true,
              (AppPaths p) async {
                await seedFile(p, 'Movies/OSD-Movie-3-2025-12-31.mp4');
                await seedFile(p, 'Movies/2025-12-31.mp4');
                await seedClip(
                  p,
                  const ProfileKey('Work'),
                  LocalDay(2024, 1, 5),
                );
                await seedFile(p, '2024-01-05_123456.mp4');
                await seedFile(p, '2024-01-05.MP4');
                await seedFile(p, '.trashed-1700000000-2024-01-05.mp4');
                await seedFile(p, 'notes.txt');
              },
              null,
              false,
            ),
            (
              'a diary folder, no storage permission',
              freshInstallPrefs,
              false,
              (_) async {},
              VideoOrientation.landscape,
              true,
            ),
            (
              'no diary folder, no storage permission',
              freshInstallPrefs,
              false,
              (AppPaths p) => Directory(p.videos).delete(recursive: true),
              null,
              false,
            ),
            for (final bool canRead in <bool>[true, false])
              (
                'an interrupted onboarding (gallery: $canRead)',
                <String, Object>{
                  'profiles': <String>['Default'],
                  'orientation_': 'portrait',
                },
                canRead,
                (AppPaths p) => seedClip(
                  p,
                  ProfileKey.defaultProfile,
                  LocalDay(2024, 1, 5),
                ),
                VideoOrientation.portrait,
                false,
              ),
          ];

      for (final (
            String name,
            Map<String, Object> prefs,
            bool canReadGallery,
            Future<void> Function(AppPaths) disk,
            VideoOrientation? fixed,
            bool warned,
          )
          in cases) {
        paths = await createTestPaths();
        log = MemoryLogSink();
        await disk(paths);
        final OnboardingStore store = await storeWith(prefs);

        expect(
          await store.fixedDefaultOrientation(canReadGallery: canReadGallery),
          fixed,
          reason: name,
        );
        if (warned) {
          // A bug report shows why the orientation choice was skipped.
          expect(
            log.lines.single,
            allOf(startsWith('[WARNING]'), contains('[ONBOARDING]')),
            reason: name,
          );
        } else {
          expect(log.lines, isEmpty, reason: name);
        }
      }
    });

    test(
      'a diary folder whose listing fails (legacy storage, Android 10 '
      'and below, answers EACCES) counts as a reinstall, as in v1.7',
      () async {
        await seedClip(paths, ProfileKey.defaultProfile, LocalDay(2024, 1, 5));
        Process.runSync('chmod', <String>['000', paths.videos]);
        addTearDown(
          () => Process.runSync('chmod', <String>['755', paths.videos]),
        );
        try {
          Directory(paths.videos).listSync();
          markTestSkipped('This user can read a mode-000 folder (root?).');
          return;
        } on FileSystemException {
          // Unreadable, as intended.
        }
        final OnboardingStore store = await storeWith(freshInstallPrefs);

        expect(
          await store.fixedDefaultOrientation(canReadGallery: true),
          VideoOrientation.landscape,
        );
        expect(
          log.lines.single,
          allOf(startsWith('[WARNING]'), contains('[ONBOARDING]')),
        );
      },
    );
  });

  group('complete', () {
    test('writes the Default profile, the first-run counters and showIntro '
        'as v1.7 did; a stored profile list is kept, so named profiles are '
        'never orphaned, and an empty one becomes Default', () async {
      final OnboardingStore fresh = await storeWith(freshInstallPrefs);

      await fresh.complete(defaultOrientation: VideoOrientation.portrait);

      expect(await storedPrefs(), _completed);
      expect(fresh.isOnboarded, isTrue);
      expect(log.lines, <String>[
        '[INFO] 2024-01-05 10:00:00.000: [ONBOARDING] Completed; Default '
            'profile is portrait',
      ]);

      final OnboardingStore named = await storeWith(<String, Object>{
        'profiles': <String>['Default', 'Work'],
        'orientation_Work': 'portrait',
      });
      await named.complete(defaultOrientation: VideoOrientation.landscape);

      final Map<String, Object> stored = await storedPrefs();
      expect(stored['profiles'], <String>['Default', 'Work']);
      expect(stored['orientation_Work'], 'portrait');
      expect(stored['orientation_'], 'landscape');

      final OnboardingStore empty = await storeWith(<String, Object>{
        'profiles': <String>[],
      });
      await empty.complete(defaultOrientation: VideoOrientation.landscape);

      expect((await storedPrefs())['profiles'], <String>['Default']);
    });

    test(
      'a retry after a kill between the profile and showIntro completes '
      'and keeps the first choice, with a warning (flips Z-06, I CL-12)',
      () async {
        // The profile and its orientation exist, showIntro does not.
        final OnboardingStore store = await storeWith(<String, Object>{
          'profiles': <String>['Default'],
          'orientation_': 'landscape',
          'videoCount': 0,
          'movieCount': 1,
        });
        expect(store.isOnboarded, isFalse);

        await store.complete(defaultOrientation: VideoOrientation.portrait);

        expect(store.isOnboarded, isTrue);
        expect((await storedPrefs())['orientation_'], 'landscape');
        expect(log.lines, <String>[
          '[WARNING] 2024-01-05 10:00:00.000: [ONBOARDING] Asked for portrait, '
              'but the Default profile is already landscape; keeping it',
          '[INFO] 2024-01-05 10:00:00.000: [ONBOARDING] Completed; Default '
              'profile is landscape',
        ]);
      },
    );

    test('showIntro is written last: if an earlier write fails the user is '
        'not onboarded, and a retry completes', () async {
      for (final String failing in <String>[
        'profiles',
        'orientation_',
        'videoCount',
        'movieCount',
      ]) {
        final (
          PrefsStore prefs,
          RefusingSharedPreferences platform,
        ) = await openRefusingPrefs(
          freshInstallPrefs,
          refused: <String>{failing},
        );
        final OnboardingStore store = storeOver(prefs);

        await expectLater(
          store.complete(defaultOrientation: VideoOrientation.portrait),
          throwsA(isA<StorageException>()),
          reason: failing,
        );
        expect(store.isOnboarded, isFalse, reason: failing);

        platform.refused.clear();
        await store.complete(defaultOrientation: VideoOrientation.portrait);

        expect(store.isOnboarded, isTrue, reason: failing);
        expect(await storedPrefs(), _completed, reason: failing);
      }
    });
  });
}

/// Everything in the preference store, by key.
Future<Map<String, Object>> storedPrefs() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return <String, Object>{
    for (final String key in prefs.getKeys()) key: prefs.get(key)!,
  };
}
