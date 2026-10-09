import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/settings/domain/settings_platform.dart';

void main() {
  test('iOS hides the donation links and the persistent reminder and warns '
      'that deleting the app deletes the videos; the Backup & restore sheet '
      'shows on both platforms; Android shows everything', () {
    const SettingsPlatform ios = SettingsPlatform(isIOS: true);
    const SettingsPlatform android = SettingsPlatform(isIOS: false);

    expect(
      <(bool, bool, bool, bool)>[
        for (final SettingsPlatform platform in <SettingsPlatform>[
          ios,
          android,
        ])
          (
            platform.showsDonationLinks,
            platform.showsBackupSheet,
            platform.showsPersistentReminder,
            platform.showsBackupWarning,
          ),
      ],
      <(bool, bool, bool, bool)>[
        (false, true, false, true),
        (true, true, true, false),
      ],
    );
  });
}
