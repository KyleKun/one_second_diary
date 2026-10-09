// ignore_for_file: file_names

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/presentation/imports/process_imports_sheet.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/presentation/pages/settings_tab_page.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/backup_sheet.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_step_row.dart';

import '../../shared/harness/settle.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

void main() {
  // Bring videos in: a `.mov` named like a clip but not made by the app is found by
  // "Look for new videos", and closing the sheet prompts to process it.
  testWidgets('Settings › Backup & restore › Bring videos in › Look for new '
      'videos finds a video copied beside the clips; closing the sheet '
      'prompts "1 imported video · Process", and Process opens the '
      'processing sheet', (WidgetTester tester) async {
    late AppPaths paths;
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      isAndroid: true,
      seed: (AppPaths at) async {
        paths = at;
        await seedClip(at, ProfileKey.defaultProfile, LocalDay(2024, 1, 2));
      },
    );
    // Copied in after the launch scan: only the sheet's scan can find it.
    await tester.runAsync(() => seedFile(paths, '2024-01-03.mov'));

    await app.settings.tapRow(SettingsTabPage.backupRowKey);
    expect(find.byKey(BackupSheet.bodyKey), findsOneWidget);
    await tester.tap(find.byKey(BackupSheet.bringInChoiceKey));
    await settle(tester);
    final Finder look = find.ancestor(
      of: find.text(Strings.backupLookForNewVideos),
      matching: find.byKey(OsdStepRow.actionKey),
    );
    await tester.ensureVisible(look);
    await settle(tester);
    await tester.tap(look);
    await app.harness.settleUntil(
      () => find.text(Strings.backupFoundClips(1)).evaluate().isNotEmpty,
      reason: 'the scan finds the copied video',
    );

    Navigator.of(tester.element(find.byKey(BackupSheet.bodyKey))).pop();
    await app.harness.settleUntil(
      () =>
          find.byKey(BackupSheet.bodyKey).evaluate().isEmpty &&
          find
              .descendant(
                of: find.byKey(OsdSnackbar.surfaceKey),
                matching: find.text(
                  Strings.importedVideosProcess(
                    videos: Strings.importedVideoCount(1),
                  ),
                ),
              )
              .evaluate()
              .isNotEmpty,
      reason: 'the page prompts to process the imported video',
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(OsdSnackbar.surfaceKey),
        matching: find.text(Strings.processImport),
      ),
    );
    await app.harness.settleUntil(
      () => find.byKey(ProcessImportsSheet.bodyKey).evaluate().isNotEmpty,
      reason: 'the processing sheet opens',
    );
    expect(find.text(Strings.processImportsTitle), findsOneWidget);
    await app.harness.settleUntil(
      () => find.byKey(ProcessImportsSheet.startKey).evaluate().isNotEmpty,
      reason: 'the sheet lists what was found and offers to process it',
    );
    expect(find.byKey(ProcessImportsSheet.keepFirstKey), findsOneWidget);
    expect(find.byKey(ProcessImportsSheet.dateStampKey), findsOneWidget);
    app.expectNoPluginChannel();
  });
}
