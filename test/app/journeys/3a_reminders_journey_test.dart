// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/features/settings/presentation/pages/settings_tab_page.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

void main() {
  testWidgets('a user turns the daily reminder on, allows it, and moves it '
      'to 7:30', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    await app.settings.open();
    expect(
      app.settings.valueOf(SettingsTabPage.notificationsRowKey),
      Strings.settingsValueOff,
    );
    expect(app.harness.gateways.permissions.requestedTogether, isEmpty);

    await app.reminders.open();
    await app.reminders.tapDailyReminder();

    expect(
      app.harness.gateways.permissions.requestedTogether,
      <Set<AppPermission>>[
        <AppPermission>{AppPermission.notifications},
      ],
    );
    expect(app.reminders.reminderSwitchOn, isTrue);
    await app.reminders.expectPlannedAt(hour: 20, minute: 0);

    await app.reminders.setTime(hour: 7, minute: 30);

    expect(app.reminders.shownTime, '7:30 AM');
    await app.reminders.expectPlannedAt(hour: 7, minute: 30);
    await app.reminders.expectEveryTitle(Strings.notificationTitle);
    await app.shell.pressBack();
    expect(
      app.settings.valueOf(SettingsTabPage.notificationsRowKey),
      '7:30 AM',
    );
    app.expectNoPluginChannel();
  });

  testWidgets('a user who refuses the permission sees why, allows it in the '
      "phone's settings, and comes back to turn it on", (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      configureGateways: (FakeGateways gateways) =>
          gateways.permissions.answers[AppPermission.notifications] =
              AppPermissionStatus.permanentlyDenied,
    );
    await app.reminders.open();

    await app.reminders.tapDailyReminder();

    expect(app.reminders.reminderSwitchOn, isFalse);
    app.reminders.expectBlockedBanner(shown: true);
    expect(app.harness.gateways.notifications.scheduled, isEmpty);

    await app.reminders.tapOpenSettings();
    expect(app.harness.gateways.permissions.settingsOpened, isTrue);
    app.harness.gateways.permissions.statuses[AppPermission.notifications] =
        AppPermissionStatus.granted;
    await app.reminders.resumeApp();

    app.reminders.expectBlockedBanner(shown: false);
    await app.reminders.tapDailyReminder();
    expect(app.reminders.reminderSwitchOn, isTrue);
    await app.reminders.expectPlannedAt(hour: 20, minute: 0);
    app.expectNoPluginChannel();
  });

  testWidgets('a user turns the reminder off: nothing stays planned, and S1 '
      'says "Off"', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(
        extra: <String, Object>{'activatedNotification': true},
      ),
      configureGateways: (FakeGateways gateways) =>
          gateways.permissions.statuses[AppPermission.notifications] =
              AppPermissionStatus.granted,
    );
    await app.reminders.open();
    await app.reminders.expectPlannedAt(hour: 20, minute: 0);

    await app.reminders.tapDailyReminder();

    await app.reminders.expectNonePlanned();
    await app.shell.pressBack();
    expect(
      app.settings.valueOf(SettingsTabPage.notificationsRowKey),
      Strings.settingsValueOff,
    );
  });
}
