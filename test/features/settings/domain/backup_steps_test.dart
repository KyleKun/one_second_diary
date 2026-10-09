// The Backup & restore sheet's steps per platform and mode:
// 4–5 numbered steps, the import path ending with
// "Look for new videos", iOS with "Open in Files", Android with "Copy path";
// the Files app URL is percent-encoded.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/settings/domain/backup_steps.dart';

void main() {
  test('each platform × mode has its ordered steps with the actions each '
      'carries; the Android video link only on the back-up steps', () {
    List<(BackupStepText, BackupStepAction?)> steps(
      BackupPlatform platform,
      BackupMode mode,
    ) => <(BackupStepText, BackupStepAction?)>[
      for (final BackupStep step in BackupSteps.of(
        platform: platform,
        mode: mode,
      ))
        (step.text, step.action),
    ];

    expect(
      steps(BackupPlatform.android, BackupMode.backUp),
      <(BackupStepText, BackupStepAction?)>[
        (BackupStepText.androidBackup1, BackupStepAction.copyPath),
        (BackupStepText.androidBackup2, null),
        (BackupStepText.androidBackup3, null),
        (BackupStepText.androidBackup4, null),
        (BackupStepText.androidBackup5, null),
      ],
    );
    expect(
      steps(BackupPlatform.ios, BackupMode.backUp),
      <(BackupStepText, BackupStepAction?)>[
        (BackupStepText.iosBackup1, null),
        (BackupStepText.iosBackup2, BackupStepAction.openInFiles),
        (BackupStepText.iosBackup3, null),
        (BackupStepText.iosBackup4, null),
      ],
    );
    expect(
      steps(BackupPlatform.android, BackupMode.bringIn),
      <(BackupStepText, BackupStepAction?)>[
        (BackupStepText.androidImport1, BackupStepAction.copyPath),
        (BackupStepText.importDateNamed, null),
        (BackupStepText.importLook, BackupStepAction.lookForNewVideos),
        (BackupStepText.importProcessed, null),
      ],
    );
    expect(
      steps(BackupPlatform.ios, BackupMode.bringIn),
      <(BackupStepText, BackupStepAction?)>[
        (BackupStepText.iosImport1, BackupStepAction.openInFiles),
        (BackupStepText.importDateNamed, null),
        (BackupStepText.importLook, BackupStepAction.lookForNewVideos),
        (BackupStepText.importProcessed, null),
      ],
    );

    expect(
      <bool>[
        for (final BackupPlatform platform in BackupPlatform.values)
          for (final BackupMode mode in BackupMode.values)
            BackupSteps.showsVideoLink(platform: platform, mode: mode),
      ],
      <bool>[true, false, false, false],
    );
    expect(
      BackupStepText.values.where((BackupStepText t) => t.takesPath),
      <BackupStepText>[
        BackupStepText.androidBackup1,
        BackupStepText.androidImport1,
      ],
    );
  });

  test('the Files app URL is shareddocuments:// plus the folder, '
      'percent-encoded (a space becomes %20), without a trailing slash', () {
    expect(
      BackupSteps.filesAppUri(
        '/private/var/mobile/Containers/Data/Application Support/OneSecondDiary/',
      ).toString(),
      'shareddocuments:///private/var/mobile/Containers/Data/'
      'Application%20Support/OneSecondDiary',
    );
  });
}
