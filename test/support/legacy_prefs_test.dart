import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import 'legacy_prefs.dart';

void main() {
  test('the default seed is an onboarded v1.7.1 install; null leaves a key '
      'out and extra adds any other key', () async {
    final PrefsStore onboarded = await openLegacyPrefs(legacyPrefs());

    expect(onboarded.read(PrefKeys.showIntro), isFalse);
    expect(onboarded.read(PrefKeys.profiles), <String>['Default']);
    expect(onboarded.read(PrefKeys.selectedProfileIndex), 0);
    expect(
      onboarded.read(PrefKeys.orientation(ProfileKey.defaultProfile)),
      'landscape',
    );
    expect(onboarded.read(PrefKeys.videoCount), 0);
    expect(onboarded.read(PrefKeys.movieCount), 1);
    expect(onboarded.contains(PrefKeys.isDarkMode), isFalse);

    final PrefsStore custom = await openLegacyPrefs(
      legacyPrefs(
        showIntro: null,
        profiles: <String>['Default', 'Kids'],
        selectedProfileIndex: 1,
        orientations: <String, String>{'': 'landscape', 'Kids': 'portrait'},
        movieCount: null,
        extra: <String, Object>{PrefKeys.isDarkMode.name: false},
      ),
    );

    expect(custom.contains(PrefKeys.showIntro), isFalse);
    expect(custom.contains(PrefKeys.movieCount), isFalse);
    expect(
      custom.read(PrefKeys.orientation(const ProfileKey('Kids'))),
      'portrait',
    );
    expect(custom.read(PrefKeys.isDarkMode), isFalse);
  });

  test('a fresh install has nothing stored', () async {
    final PrefsStore prefs = await openLegacyPrefs(freshInstallPrefs);

    for (final key in PrefKeys.all) {
      expect(prefs.contains(key), isFalse, reason: key.name);
    }
  });
}
