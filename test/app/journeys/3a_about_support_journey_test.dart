// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/settings/domain/app_links.dart';
import 'package:one_second_diary/features/settings/domain/changelog.dart';
import 'package:one_second_diary/features/settings/domain/credits.dart';
import 'package:one_second_diary/features/settings/presentation/pages/settings_tab_page.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/backup_sheet.dart';

import '../../shared/harness/settle.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

void main() {
  testWidgets('a user reads About: the version, the newest changes, the '
      "people thanked (one's profile opens), the licences, and back to "
      'Settings', (WidgetTester tester) async {
    final ChangelogRelease newest = Changelog.parse(
      File('CHANGELOG.md').readAsStringSync(),
    ).first;
    final CreditsPerson contributor =
        Credits.parse(File('CONTRIBUTORS.md').readAsStringSync())
            .firstWhere(
              (CreditsSection s) => s.kind == CreditsKind.contributors,
            )
            .people
            .first;
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());

    await app.settings.openAbout();
    app.settings.expectAbout(version: 'Version 2.0.0');

    await app.settings.openAboutPage(AppRoute.changelog);
    app.settings.expectChangelogShows(newest);
    await app.shell.pressBack();

    await app.settings.openAboutPage(AppRoute.thanks);
    await app.settings.tapThanked(contributor.name);
    expect(app.harness.gateways.urls.opened, <Uri>[contributor.link!]);
    await app.shell.pressBack();

    await app.settings.openAboutPage(AppRoute.licenses);
    app.settings.expectLicences();
    await app.shell.pressBack();
    await app.shell.pressBack();

    app.shell
      ..expectAt(AppRoute.settings)
      ..expectActiveTab(AppRoute.settings);
    app.expectNoPluginChannel();
  });

  testWidgets('a user supports the app: a coffee, then GitHub Sponsors, and '
      'closes the page', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      isAndroid: true,
    );

    await app.settings.openSupport();
    await app.settings.tapBuyMeACoffee();
    await app.settings.tapGitHubSponsors();
    expect(app.harness.gateways.urls.opened, <Uri>[
      AppLinks.buyMeACoffee,
      AppLinks.githubSponsors,
    ]);

    await app.settings.closeSupport();
    app.shell.expectAt(AppRoute.settings);
    app.expectNoPluginChannel();
  });

  // The backup row opens the Backup & restore sheet; the tutorial video is a link
  // inside its "Save a copy" steps on Android.
  testWidgets('on Android a user shares the app, then opens the source code '
      'and, from the backup sheet, the tutorial video; a link the phone '
      'cannot open is copied', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      isAndroid: true,
    );

    await app.settings.tapRow(SettingsTabPage.shareRowKey);
    expect(app.harness.gateways.share.sharedTexts, <String>[
      Strings.shareAppMessage(url: 'https://oneseconddiary.com/share'),
    ]);

    await app.settings.tapRow(SettingsTabPage.websiteRowKey);
    await app.settings.tapRow(SettingsTabPage.sourceCodeRowKey);
    await app.settings.tapRow(SettingsTabPage.backupRowKey);
    expect(find.byKey(BackupSheet.bodyKey), findsOneWidget);
    await tester.tap(find.byKey(BackupSheet.saveChoiceKey));
    await settle(tester);
    await tester.ensureVisible(find.byKey(BackupSheet.watchVideoKey));
    await tester.tap(find.byKey(BackupSheet.watchVideoKey));
    await settle(tester);
    expect(app.harness.gateways.urls.opened, <Uri>[
      AppLinks.website,
      AppLinks.repository,
      AppLinks.backupTutorial,
    ]);
    Navigator.of(tester.element(find.byKey(BackupSheet.bodyKey))).pop();
    await settle(tester);
    expect(find.byKey(BackupSheet.bodyKey), findsNothing);

    app.harness.gateways.urls.result = false;
    await app.settings.tapRow(SettingsTabPage.sourceCodeRowKey);
    expect(find.text(Strings.linkOpenFailed), findsOneWidget);
    expect(find.text(Strings.copyLink), findsOneWidget);
    app.expectNoPluginChannel();
  });
}
