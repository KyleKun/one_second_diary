import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/reminders/domain/planned_reminder.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_plan.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_settings.dart';
import 'package:timezone/timezone.dart' as tz;

/// Decides which daily reminders to schedule. Pure: no clock, no plugin.
///
/// Plans one notification per day for the next [windowDays] days, each at the
/// chosen wall-clock time in the user's zone (so a DST change never shifts
/// it), leaving out recorded days and instants not in the future.
final class ReminderPlanner {
  const ReminderPlanner();

  /// How many days ahead a plan reaches. Re-plans (app start, a recording,
  /// a settings or locale change) keep it topped up.
  static const int windowDays = 14;

  /// The single daily repeating reminder of older installs. No plan uses
  /// this id, so that the scheduler can always cancel it: left alone, it
  /// would keep firing next to the planned reminders.
  static const int legacyReminderId = 1;

  static const int _firstId = 2;

  /// Every id a plan can use: one per slot of the window.
  static final List<int> reminderIds = List<int>.unmodifiable(<int>[
    for (int slot = 0; slot < windowDays; slot++) _firstId + slot,
  ]);

  /// The notification id of [day]'s reminder. A day keeps its id from one
  /// plan to the next, so a re-plan can leave the reminder on screen alone,
  /// and days in one window never share an id.
  static int idFor(LocalDay day) => _firstId + day.epochDay % windowDays;

  /// The plan for [settings] at [now] in the user's [location].
  /// [isRecorded] says whether the active profile has a clip on a day (for
  /// example `ClipIndex.hasDay`); only the [windowDays] days of the window
  /// are looked up, so the index is never copied.
  ReminderPlan plan({
    required ReminderSettings settings,
    required bool Function(LocalDay day) isRecorded,
    required DateTime now,
    required tz.Location location,
  }) {
    if (!settings.enabled) {
      return const ReminderPlan(reminders: <PlannedReminder>[]);
    }
    final tz.TZDateTime localNow = tz.TZDateTime.from(now, location);
    final LocalDay today = LocalDay(
      localNow.year,
      localNow.month,
      localNow.day,
    );
    final List<PlannedReminder> window = <PlannedReminder>[
      for (int offset = 0; offset < windowDays; offset++)
        _reminderOn(today.addDays(offset), settings, location),
    ];
    bool isDue(PlannedReminder reminder) => !reminder.at.isAfter(now);
    bool isDone(PlannedReminder reminder) => isRecorded(reminder.day);
    final PlannedReminder todays = window.first;
    return ReminderPlan(
      reminders: <PlannedReminder>[
        for (final PlannedReminder reminder in window)
          if (!isDue(reminder) && !isDone(reminder)) reminder,
      ],
      dueTodayId: isDue(todays) && !isDone(todays) ? todays.id : null,
    );
  }

  /// [day]'s reminder at the chosen wall-clock time. A time inside a DST gap
  /// moves forward by the gap on the same day (Santiago's missing midnight
  /// becomes 01:00); an ambiguous time picks one of its two instants.
  static PlannedReminder _reminderOn(
    LocalDay day,
    ReminderSettings settings,
    tz.Location location,
  ) => PlannedReminder(
    id: idFor(day),
    day: day,
    at: tz.TZDateTime(
      location,
      day.year,
      day.month,
      day.day,
      settings.hour,
      settings.minute,
    ),
  );
}
