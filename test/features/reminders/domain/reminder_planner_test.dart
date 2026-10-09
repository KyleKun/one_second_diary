import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/reminders/domain/planned_reminder.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_plan.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_planner.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_settings.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location berlin;

  setUpAll(() {
    tz_data.initializeTimeZones();
    berlin = tz.getLocation('Europe/Berlin');
  });

  const ReminderPlanner planner = ReminderPlanner();

  const ReminderSettings at20 = ReminderSettings(
    enabled: true,
    persistent: false,
    time: (hour: 20, minute: 0),
  );

  const ReminderSettings off = ReminderSettings(
    enabled: false,
    persistent: false,
    time: (hour: 20, minute: 0),
  );

  ReminderPlan planAt(
    tz.TZDateTime now, {
    ReminderSettings settings = at20,
    Set<LocalDay> recorded = const <LocalDay>{},
  }) => planner.plan(
    settings: settings,
    isRecorded: recorded.contains,
    now: now,
    location: now.location,
  );

  test('plans the 14 days from today at the chosen local time, asking only '
      'about the days of its window (a caller passes ClipIndex.hasDay and '
      'never copies the index); nothing while reminders are off', () {
    final Set<LocalDay> asked = <LocalDay>{};
    final ReminderPlan plan = planner.plan(
      settings: at20,
      isRecorded: (LocalDay day) {
        asked.add(day);
        return false;
      },
      now: tz.TZDateTime(berlin, 2026, 1, 10, 9),
      location: berlin,
    );

    expect(plan.reminders.map((PlannedReminder r) => (r.day, r.at)), <
      (LocalDay, DateTime)
    >[
      for (int i = 0; i < 14; i++)
        (LocalDay(2026, 1, 10 + i), tz.TZDateTime(berlin, 2026, 1, 10 + i, 20)),
    ]);
    expect(asked, <LocalDay>{
      for (int offset = 0; offset < ReminderPlanner.windowDays; offset++)
        LocalDay(2026, 1, 10).addDays(offset),
    });
    expect(
      planAt(tz.TZDateTime(berlin, 2026, 1, 10, 9), settings: off).reminders,
      isEmpty,
    );
  });

  test("skips today once today's time has passed: no instant in the past "
      '(v1.7 rescheduled today at 21:30 for 20:00, issue #112); skips the '
      'days already recorded, today included, taking them as given (just '
      'after midnight, with only yesterday recorded, today keeps its '
      'reminder)', () {
    final tz.TZDateTime evening = tz.TZDateTime(berlin, 2026, 9, 28, 21, 30);
    final ReminderPlan late = planAt(evening);

    expect(late.reminders.first.day, LocalDay(2026, 9, 29));
    expect(late.reminders.last.day, LocalDay(2026, 10, 11));
    expect(
      late.reminders.every((PlannedReminder r) => r.at.isAfter(evening)),
      isTrue,
    );

    final ReminderPlan recorded = planAt(
      tz.TZDateTime(berlin, 2026, 9, 28, 9),
      recorded: <LocalDay>{LocalDay(2026, 9, 28), LocalDay(2026, 9, 30)},
    );

    expect(
      recorded.reminders.map((PlannedReminder r) => r.day).take(3),
      <LocalDay>[
        LocalDay(2026, 9, 29),
        LocalDay(2026, 10, 1),
        LocalDay(2026, 10, 2),
      ],
    );
    expect(recorded.reminders, hasLength(12));

    // Which day a clip belongs to is decided when it is saved, not here.
    final ReminderPlan midnight = planAt(
      tz.TZDateTime(berlin, 2026, 9, 29, 0, 0, 20),
      recorded: <LocalDay>{LocalDay(2026, 9, 28)},
    );

    expect(midnight.reminders.first.day, LocalDay(2026, 9, 29));
    expect(midnight.reminders.first.at, tz.TZDateTime(berlin, 2026, 9, 29, 20));
  });

  test('across daylight-saving changes every reminder stays at the chosen '
      'local time: Berlin in autumn (20:00 CEST, then CET) and spring (20:00 '
      'CET, then CEST); Santiago\'s midnight reminder on the day without a '
      'midnight fires at 01:00 that day, every other day at 00:00', () {
    for (final (tz.TZDateTime now, int before, (int, int) utcHours)
        in <(tz.TZDateTime, int, (int, int))>[
          // 10-24 is the last CEST day.
          (tz.TZDateTime(berlin, 2026, 10, 20, 9), 4, (18, 19)),
          // 03-28 is the last CET day.
          (tz.TZDateTime(berlin, 2026, 3, 25, 9), 3, (19, 18)),
        ]) {
      final ReminderPlan plan = planAt(now);

      expect(
        plan.reminders.map((PlannedReminder r) => (r.at.hour, r.at.minute)),
        everyElement((20, 0)),
        reason: '$now',
      );
      expect(
        (
          plan.reminders[before].at.toUtc().hour,
          plan.reminders[before + 1].at.toUtc().hour,
        ),
        utcHours,
        reason: '$now',
      );
    }

    final tz.Location santiago = tz.getLocation('America/Santiago');
    final ReminderPlan plan = planAt(
      tz.TZDateTime(santiago, 2026, 9, 4, 12),
      settings: const ReminderSettings(
        enabled: true,
        persistent: false,
        time: (hour: 0, minute: 0),
      ),
    );

    expect(
      plan.reminders
          .take(3)
          .map((PlannedReminder r) => (r.day, r.at.day, r.at.hour)),
      <(LocalDay, int, int)>[
        (LocalDay(2026, 9, 5), 5, 0),
        (LocalDay(2026, 9, 6), 6, 1),
        (LocalDay(2026, 9, 7), 7, 0),
      ],
    );
  });

  test('notification ids are unique within a plan and never 1, the id of '
      'the daily repeating reminder of v1.7; a day keeps its id from one '
      'plan to the next', () {
    Map<LocalDay, int> idsByDay(tz.TZDateTime now) => <LocalDay, int>{
      for (final PlannedReminder r in planAt(now).reminders) r.day: r.id,
    };
    final Map<LocalDay, int> monday = idsByDay(
      tz.TZDateTime(berlin, 2026, 9, 28, 9),
    );
    final Map<LocalDay, int> tuesday = idsByDay(
      tz.TZDateTime(berlin, 2026, 9, 29, 9),
    );

    expect(monday.values.toSet(), hasLength(14));
    expect(ReminderPlanner.legacyReminderId, 1);
    expect(monday.values, isNot(contains(ReminderPlanner.legacyReminderId)));
    expect(ReminderPlanner.reminderIds, containsAll(monday.values));
    for (final LocalDay day in tuesday.keys.where(monday.containsKey)) {
      expect(tuesday[day], monday[day], reason: '$day');
    }
  });

  test("today's due reminder (it may be on screen) is kept while today is "
      'not recorded, so a persistent one stays until that day is recorded; '
      'it is not kept once today is recorded (issue #66), and it is nothing '
      'before its time or while reminders are off', () {
    final tz.TZDateTime evening = tz.TZDateTime(berlin, 2026, 9, 28, 21, 30);

    expect(
      planAt(evening).dueTodayId,
      ReminderPlanner.idFor(LocalDay(2026, 9, 28)),
    );
    expect(
      planAt(evening, recorded: <LocalDay>{LocalDay(2026, 9, 28)}).dueTodayId,
      isNull,
    );
    expect(planAt(evening, settings: off).dueTodayId, isNull);

    final ReminderPlan morning = planAt(tz.TZDateTime(berlin, 2026, 9, 28, 9));
    expect(morning.dueTodayId, isNull);
    expect(morning.reminders.first.day, LocalDay(2026, 9, 28));
  });
}
