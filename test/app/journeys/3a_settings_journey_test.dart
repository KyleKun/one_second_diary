// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/presentation/pages/settings_tab_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

void main() {
  testWidgets('a user picks German in the language sheet: the whole app '
      'changes in place, and the reminders follow', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(
        extra: <String, Object>{'activatedNotification': true},
      ),
    );
    await app.settings.open();
    final Element settingsTab = app.shell.pageElement(AppRoute.settings);

    await app.settings.openLanguageSheet();
    expect(app.settings.checkedLanguage, AppLanguage.en);
    await app.settings.pickLanguage(AppLanguage.de);

    app.settings.expectLanguageSheetOpen(open: false);
    app.shell
      ..expectAt(AppRoute.settings)
      ..expectPageTitle(AppRoute.settings, 'Einstellungen')
      ..expectNavLabels(<String>['Heute', 'Diary', 'Journey', 'Einstellungen']);
    expect(app.shell.pageElement(AppRoute.settings), same(settingsTab));
    expect(app.settings.valueOf(SettingsTabPage.languageRowKey), 'Deutsch');
    expect(app.settings.valueOf(SettingsTabPage.profilesRowKey), 'Standard');
    expect((await SharedPreferences.getInstance()).getString('lang'), 'de');
    await app.reminders.expectEveryTitle('Hallo!');

    await app.settings.pickLanguage(AppLanguage.en);
    app.shell.expectPageTitle(AppRoute.settings, 'Settings');
    app.expectNoPluginChannel();
  });

  testWidgets('a user switches to the light theme and back from S1', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    app.expectBrightness(Brightness.dark);

    await app.settings.tapRow(SettingsTabPage.darkModeRowKey);
    app.expectBrightness(Brightness.light);
    expect(app.settings.darkModeSwitchOn, isFalse);
    expect(
      (await SharedPreferences.getInstance()).getBool('isDarkMode'),
      isFalse,
    );

    await app.settings.tapRow(SettingsTabPage.darkModeRowKey);
    app.expectBrightness(Brightness.dark);
    expect(app.settings.darkModeSwitchOn, isTrue);
    app.expectNoPluginChannel();
  });

  testWidgets('a user tells the app their name; the S1 row shows it', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());

    await app.settings.setName('Kyle');

    expect(app.settings.valueOf(SettingsTabPage.yourNameRowKey), 'Kyle');
    expect(
      (await SharedPreferences.getInstance()).getString('userName'),
      'Kyle',
    );
  });

  // The Backup & restore sheet shows on both platforms; only "Support the app" is Android's.
  testWidgets('on iOS S1 has no "Support the app" but keeps Backup & '
      'restore', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      isIOS: true,
    );
    await app.settings.open();

    app.settings
      ..expectRow(SettingsTabPage.supportRowKey, shown: false)
      ..expectRow(SettingsTabPage.backupRowKey)
      ..expectRow(SettingsTabPage.sourceCodeRowKey);
  });
}
