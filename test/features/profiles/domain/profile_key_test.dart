import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

void main() {
  // The clips' `album` tag and every log line name a profile by its key,
  // never by its display name, which can change.
  test('index 0 of the legacy profiles list is Default (the empty key), '
      'whatever its label; a later profile labelled "Default" is not Default; '
      'keys compare by folder name; the album label is "Default" for '
      'Default, else the key', () {
    expect(ProfileKey.fromLegacyIndex(0, 'Default'), ProfileKey.defaultProfile);
    expect(ProfileKey.fromLegacyIndex(0, 'Home'), ProfileKey.defaultProfile);
    expect(
      ProfileKey.fromLegacyIndex(2, 'Default'),
      const ProfileKey('Default'),
    );
    expect(ProfileKey.fromLegacyIndex(1, 'Work'), const ProfileKey('Work'));

    expect(
      <(ProfileKey, bool, String)>[
        for (final ProfileKey key in <ProfileKey>[
          ProfileKey.defaultProfile,
          const ProfileKey(''),
          const ProfileKey('Default'),
          const ProfileKey('Work'),
        ])
          (key, key.isDefault, key.albumLabel),
      ],
      <(ProfileKey, bool, String)>[
        (ProfileKey.defaultProfile, true, 'Default'),
        (ProfileKey.defaultProfile, true, 'Default'),
        (const ProfileKey('Default'), false, 'Default'),
        (const ProfileKey('Work'), false, 'Work'),
      ],
    );
    expect(const ProfileKey('Work'), isNot(const ProfileKey('work')));
  });
}
