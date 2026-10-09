import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/notifications_gateway.dart';
import 'package:one_second_diary/core/platform/pending_notification.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/local_time_zone.dart';
import 'package:one_second_diary/features/reminders/domain/planned_reminder.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_plan.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_planner.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_settings.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_text.dart';
import 'package:timezone/timezone.dart' as tz;

/// Keeps the scheduled reminders in line with the settings and the diary.
///
/// [replan] is the one entry point; every trigger calls it (app start, a
/// settings change, a recording saved or deleted, a profile switch, a language
/// change). It derives everything at call time (stored settings, device zone,
/// clock), so a caller cannot schedule while the switch is off.
///
/// A re-plan cancels, then schedules the plan (`ReminderPlanner`):
/// - switch off: everything is cancelled, including a reminder on screen;
/// - the repeating reminder of older installs
///   (`ReminderPlanner.legacyReminderId`) is always cancelled;
/// - every day slot is re-scheduled, except today's reminder when it is
///   already on screen and today is not recorded (a persistent reminder stays
///   until that day is recorded).
///
/// Permission is asked by the settings screen, not here.
///
/// A plain class (not final), so cubit tests can fake it.
class ReminderScheduler {
  /// [readSettings] reads the stored reminder settings at each re-plan
  /// (never a cached copy), from `SettingsRepository`: `remindersEnabled`,
  /// `persistentReminder` and `reminderTime` (the only writer of those
  /// keys, which also guards against an out-of-range stored time).
  ReminderScheduler({
    required this._notifications,
    required this._readSettings,
    required this._timeZone,
    required this._clock,
    required this._logger,
  });

  static const String _tag = 'NOTIFICATIONS';

  final NotificationsGateway _notifications;
  final ReminderSettings Function() _readSettings;
  final LocalTimeZone _timeZone;
  final Clock _clock;
  final AppLogger _logger;

  /// The tail of the re-plans in flight: they run one at a time, in call
  /// order, so the last call's plan is what stays scheduled.
  Future<void> _replans = Future<void>.value();

  /// Re-plans the reminders. [text] is the title and body in the app's current
  /// language; [isRecorded] says whether the active profile has a clip on a day
  /// (only the next 14 days are looked up). Never throws: a failure is logged,
  /// and the next call starts afresh.
  Future<void> replan({
    required ReminderText text,
    required bool Function(LocalDay day) isRecorded,
  }) => _replans = _replans.then(
    (_) => _replanOnce(text: text, isRecorded: isRecorded),
  );

  Future<void> _replanOnce({
    required ReminderText text,
    required bool Function(LocalDay day) isRecorded,
  }) async {
    try {
      final ReminderSettings settings = _readSettings();
      if (!settings.enabled) {
        await _notifications.cancelAll();
        _logger.info(_tag, 'Reminders are off: nothing scheduled');
        return;
      }
      final tz.Location location = await _timeZone.resolve();
      final ReminderPlan plan = const ReminderPlanner().plan(
        settings: settings,
        isRecorded: isRecorded,
        now: _clock.now(),
        location: location,
      );
      await _cancelAllBut(await _shownTodayId(plan));
      for (final PlannedReminder reminder in plan.reminders) {
        await _notifications.schedule(
          id: reminder.id,
          at: reminder.at,
          title: text.title,
          body: text.body,
          persistent: settings.persistent,
        );
      }
      _logger.info(_tag, _describe(plan, settings, location));
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not plan the reminders',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Today's due reminder, when the OS has delivered it (it is no longer
  /// pending, so it is on screen or was dismissed). One still pending was
  /// planned for another time of today (the user changed the time) or is
  /// late (inexact delivery, and the app is open anyway): it goes.
  Future<int?> _shownTodayId(ReminderPlan plan) async {
    final int? due = plan.dueTodayId;
    if (due == null) return null;
    final List<PendingNotification> pending = await _notifications.pending();
    return pending.any((PendingNotification p) => p.id == due) ? null : due;
  }

  Future<void> _cancelAllBut(int? keptId) async {
    await _notifications.cancel(ReminderPlanner.legacyReminderId);
    for (final int id in ReminderPlanner.reminderIds) {
      if (id != keptId) await _notifications.cancel(id);
    }
  }

  static String _describe(
    ReminderPlan plan,
    ReminderSettings settings,
    tz.Location location,
  ) {
    final String time =
        '${_twoDigits(settings.hour)}:${_twoDigits(settings.minute)}';
    final String from = plan.reminders.isEmpty
        ? 'none left in the window'
        : 'from ${plan.reminders.first.day.fileStem}';
    return 'Planned ${plan.reminders.length} reminders at $time '
        '${location.name} ($from, persistent: ${settings.persistent})';
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
