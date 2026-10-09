import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/reminders/presentation/pages/reminders_page.dart';
import 'package:one_second_diary/features/reminders/presentation/sheets/reminder_time_sheet.dart';
import 'package:one_second_diary/features/reminders/presentation/widgets/reminder_time_text.dart';
import 'package:one_second_diary/features/settings/presentation/pages/settings_tab_page.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_callout.dart';

import '../../support/support.dart';
import '../harness/app_harness.dart';
import '../harness/settle.dart';
import 'settings_robot.dart';

/// The Notifications page as the user drives it, and the reminders as
/// the OS holds them, on the fake notification gateway.
class RemindersRobot {
  RemindersRobot(this.harness) : _settings = SettingsRobot(harness);

  final AppHarness harness;
  final SettingsRobot _settings;

  WidgetTester get tester => harness.tester;

  FakeNotificationsGateway get notifications => harness.gateways.notifications;

  /// Opens the page from the Settings tab's Notifications row.
  Future<void> open() async {
    await _settings.tapRow(SettingsTabPage.notificationsRowKey);
    expect(
      find.byKey(const ValueKey<AppRoute>(AppRoute.notifications)),
      findsOneWidget,
    );
  }

  /// Taps the "Daily reminder" row and waits for what the system answers.
  Future<void> tapDailyReminder() async {
    await tester.tap(find.byKey(RemindersPage.reminderRowKey));
    await settle(tester);
  }

  /// Whether the "Daily reminder" switch is drawn on.
  bool get reminderSwitchOn => _switchIn(RemindersPage.reminderRowKey);

  Future<void> tapPersistent() async {
    await tester.ensureVisible(find.byKey(RemindersPage.persistentRowKey));
    await tester.tap(find.byKey(RemindersPage.persistentRowKey));
    await settle(tester);
  }

  bool get persistentSwitchOn => _switchIn(RemindersPage.persistentRowKey);

  bool _switchIn(Key row) => tester
      .widget<OsdSwitch>(
        find.descendant(of: find.byKey(row), matching: find.byType(OsdSwitch)),
      )
      .value;

  /// Whether the blocked banner shows.
  void expectBlockedBanner({required bool shown}) => expect(
    find.byKey(RemindersPage.blockedBannerKey),
    shown ? findsOneWidget : findsNothing,
  );

  /// The banner's "Open settings".
  Future<void> tapOpenSettings() async {
    await tester.tap(
      find.descendant(
        of: find.byKey(RemindersPage.blockedBannerKey),
        matching: find.byKey(OsdCallout.actionKey),
      ),
    );
    await settle(tester);
  }

  /// The app comes back to the front (from the phone's settings).
  Future<void> resumeApp() async {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
  }

  /// The big time as drawn: the digits and the 12-hour day period, if any
  /// ("8:00 PM", "20:00").
  String get shownTime {
    final ReminderTimeText time = tester.widget<ReminderTimeText>(
      find.byType(ReminderTimeText),
    );
    return <String>[
      ?time.label.before,
      time.label.time,
      ?time.label.after,
    ].join(' ');
  }

  /// "Change time", then [hour]:[minute] on the picker, then Save (or
  /// Cancel when [save] is false).
  Future<void> setTime({
    required int hour,
    required int minute,
    bool save = true,
  }) async {
    await tester.tap(find.byKey(RemindersPage.changeTimeKey));
    await settle(tester);
    expect(find.byKey(ReminderTimeSheet.pickerKey), findsOneWidget);
    // The wheels report what they settle on; this is what they report.
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2000, 1, 1, hour, minute));
    await tester.tap(
      find.byKey(
        save ? ReminderTimeSheet.saveKey : ReminderTimeSheet.cancelKey,
      ),
    );
    await settle(tester);
  }

  /// Waits until at least one reminder is planned and every one is titled
  /// [title] (a re-plan runs in the services the launch built).
  Future<void> expectEveryTitle(String title) async {
    await harness.settleUntil(
      () =>
          notifications.scheduled.isNotEmpty &&
          notifications.scheduled.values.every(
            (ScheduledNotification n) => n.title == title,
          ),
      reason:
          'every reminder titled "$title"; planned: '
          '${notifications.scheduled.values.map((n) => n.title).toSet()}',
    );
    expect(notifications.scheduled, isNotEmpty);
    expect(
      notifications.scheduled.values.map((ScheduledNotification n) => n.title),
      everyElement(title),
    );
  }

  /// Waits until the reminders are planned at [hour]:[minute], each
  /// [persistent] or not.
  Future<void> expectPlannedAt({
    required int hour,
    required int minute,
    bool persistent = false,
  }) => harness.settleUntil(
    () =>
        notifications.scheduled.isNotEmpty &&
        notifications.scheduled.values.every(
          (ScheduledNotification n) =>
              n.at.hour == hour &&
              n.at.minute == minute &&
              n.persistent == persistent,
        ),
    reason:
        'every reminder at $hour:$minute (persistent: $persistent); '
        'planned: ${notifications.scheduled.values.map((n) => n.at).toSet()}',
  );

  /// Waits until no reminder is planned.
  Future<void> expectNonePlanned() => harness.settleUntil(
    () => notifications.scheduled.isEmpty,
    reason: 'no reminder planned; planned: ${notifications.scheduled.length}',
  );

  /// A tap on reminder [id], as the OS reports it. Returns once the app has
  /// received it and drawn what it did.
  Future<void> tap(int id) async {
    final int delivered = notifications.tapsDelivered;
    notifications.tap(id);
    await harness.settleUntil(
      () => notifications.tapsDelivered > delivered,
      reason: 'the app received the tap on reminder $id',
    );
  }
}
