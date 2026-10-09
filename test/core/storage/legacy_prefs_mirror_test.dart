import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/legacy_prefs_mirror.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';

import '../../support/support.dart';
import '../../support/track_1c/refusing_shared_preferences.dart';

void main() {
  late PrefsStore prefs;
  late LegacyPrefsMirror mirror;

  setUp(() async {
    prefs = await openLegacyPrefs(legacyPrefs());
    mirror = LegacyPrefsMirror(prefs: prefs);
  });

  test(
    'writes the folders a downgraded v1.x reads from the path keys',
    () async {
      final AppPaths paths = AppPaths.forTest(Directory('/data/osd'));

      await mirror.writePathKeys(paths);

      expect(prefs.read(PrefKeys.internalDirectoryPath), '/data/osd/internal');
      expect(prefs.read(PrefKeys.appPath), '/data/osd/media/OneSecondDiary/');
      expect(
        prefs.read(PrefKeys.moviesPath),
        '/data/osd/media/OneSecondDiary/Movies/',
      );
    },
  );

  test('writes the active profile\'s day count and today\'s status the way '
      'v1.7 kept them, and rejects a negative count without writing', () async {
    await expectLater(
      mirror.writeClipCounters(
        daysRecorded: -1,
        todayRecorded: false,
        today: LocalDay(2024, 1, 5),
      ),
      throwsArgumentError,
    );
    expect(prefs.read(PrefKeys.videoCount), 0);
    expect(prefs.contains(PrefKeys.today), isFalse);

    await mirror.writeClipCounters(
      daysRecorded: 42,
      todayRecorded: true,
      today: LocalDay(2024, 1, 5),
    );

    expect(prefs.read(PrefKeys.videoCount), 42);
    expect(prefs.read(PrefKeys.dailyEntry), isTrue);
    expect(prefs.read(PrefKeys.today), '2024-01-05');
  });

  test('writes the Android SDK level, and never one on iOS', () async {
    await mirror.writeSdkVersion(28);
    expect(prefs.read(PrefKeys.sdkVersion), 28);

    // A stale value (from an Android backup restored on iOS, say) is left
    // alone rather than removed.
    final PrefsStore restored = await openLegacyPrefs(
      legacyPrefs(extra: <String, Object>{'sdkVersion': 30}),
    );
    await LegacyPrefsMirror(prefs: restored).writeSdkVersion(null);
    expect(restored.read(PrefKeys.sdkVersion), 30);

    final PrefsStore ios = await openLegacyPrefs(legacyPrefs());
    await LegacyPrefsMirror(prefs: ios).writeSdkVersion(null);
    expect(ios.contains(PrefKeys.sdkVersion), isFalse);
  });

  group('first-run counters', () {
    test('a fresh install gets the values v1.7\'s intro wrote', () async {
      final PrefsStore fresh = await openLegacyPrefs(freshInstallPrefs);

      await LegacyPrefsMirror(prefs: fresh).writeFirstRunCounters();

      expect(fresh.read(PrefKeys.videoCount), 0);
      expect(fresh.read(PrefKeys.movieCount), 1);
    });

    test('never lowers counters that are already there', () async {
      // Onboarding runs again after a kill, or on an install whose counters
      // survived: resetting movieCount to 1 would let an older version,
      // after a downgrade, overwrite OSD-Movie-1-<today>.mp4.
      final PrefsStore kept = await openLegacyPrefs(
        legacyPrefs(showIntro: null, videoCount: 12, movieCount: 4),
      );

      await LegacyPrefsMirror(prefs: kept).writeFirstRunCounters();

      expect(kept.read(PrefKeys.videoCount), 12);
      expect(kept.read(PrefKeys.movieCount), 4);
    });
  });

  // Every write is a full XML rewrite and a commit on Android
  // (`LegacySharedPreferencesPlugin`), and the clip counters are written on
  // every index change: an unchanged value is not written again. A platform
  // that refuses every write shows that no write was attempted.
  test('an unchanged value is not written again, while a missing videoCount '
      'still is (v1.7 force-unwraps it)', () async {
    final AppPaths paths = AppPaths.forTest(Directory('/data/osd'));
    final (PrefsStore refusing, _) = await openRefusingPrefs(
      <String, Object>{
        'internalDirectoryPath': paths.internal,
        'appPath': paths.videos,
        'moviesPath': paths.movies,
        'videoCount': 3,
        'dailyEntry': true,
        'today': '2024-01-05',
        'sdkVersion': 34,
      },
      refused: <String>{
        'internalDirectoryPath',
        'appPath',
        'moviesPath',
        'videoCount',
        'dailyEntry',
        'today',
        'sdkVersion',
      },
    );
    final LegacyPrefsMirror unchanged = LegacyPrefsMirror(prefs: refusing);

    await unchanged.writePathKeys(paths);
    await unchanged.writeClipCounters(
      daysRecorded: 3,
      todayRecorded: true,
      today: LocalDay(2024, 1, 5),
    );
    await unchanged.writeSdkVersion(34);

    final PrefsStore fresh = await openLegacyPrefs(freshInstallPrefs);
    await LegacyPrefsMirror(prefs: fresh).writeClipCounters(
      daysRecorded: 0,
      todayRecorded: false,
      today: LocalDay(2024, 1, 5),
    );
    expect(fresh.contains(PrefKeys.videoCount), isTrue);
    expect(fresh.contains(PrefKeys.dailyEntry), isTrue);
  });
}
