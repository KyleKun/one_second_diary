import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/local_time_zone.dart';
import 'package:one_second_diary/features/reminders/data/reminder_scheduler.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_planner.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_settings.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_text.dart';

import '../../../support/support.dart';
import '../../../support/track_1d/delivering_notifications_gateway.dart';
import '../../../support/track_1d/fake_time_zone_gateway.dart';

/// A scheduled notification with its instant in plain UTC, comparable
/// whatever `DateTime` subtype the scheduler passed.
typedef Reminder = ({
  int id,
  DateTime utc,
  String title,
  String body,
  bool persistent,
});

Reminder summary(ScheduledNotification n) => (
  id: n.id,
  utc: DateTime.fromMillisecondsSinceEpoch(
    n.at.millisecondsSinceEpoch,
    isUtc: true,
  ),
  title: n.title,
  body: n.body,
  persistent: n.persistent,
);

const ReminderSettings on20 = ReminderSettings(
  enabled: true,
  persistent: false,
  time: (hour: 20, minute: 0),
);

const ReminderSettings persistentOn20 = ReminderSettings(
  enabled: true,
  persistent: true,
  time: (hour: 20, minute: 0),
);

const ReminderSettings off = ReminderSettings(
  enabled: false,
  persistent: false,
  time: (hour: 20, minute: 0),
);

void main() {
  const ReminderText english = ReminderText(
    title: 'Heyy!',
    body: 'Do not forget to record 1 second of your day',
  );

  late FakeClock clock;
  late DeliveringNotificationsGateway notifications;
  late MemoryLogSink log;
  late FakeTimeZoneGateway zone;

  /// What the settings store holds; the scheduler reads it at each re-plan.
  late ReminderSettings stored;

  setUp(() {
    zone = FakeTimeZoneGateway('Europe/Berlin');
    // 2026-09-28 09:00 in Berlin (CEST, UTC+2).
    clock = FakeClock(DateTime.utc(2026, 9, 28, 7));
    notifications = DeliveringNotificationsGateway(clock: clock);
    addTearDown(notifications.close);
    log = MemoryLogSink();
    stored = on20;
  });

  ReminderScheduler newScheduler() => ReminderScheduler(
    notifications: notifications,
    readSettings: () => stored,
    timeZone: LocalTimeZone(gateway: zone, logger: memoryLogger(log)),
    clock: clock,
    logger: memoryLogger(log, clock: clock),
  );

  Iterable<Reminder> scheduled() => notifications.scheduled.values.map(summary);

  test("cancels v1.7's daily repeating reminder (id 1), which would keep "
      'firing at its drifted UTC time next to the v3 reminders; at app start '
      'with reminders on, schedules one reminder a day for the next 14 days '
      'at the chosen local time, in the given language, and logs the plan '
      'for bug reports', () async {
    // What an older install left scheduled.
    await notifications.schedule(
      id: ReminderPlanner.legacyReminderId,
      at: DateTime.utc(2026, 9, 28, 20),
      title: english.title,
      body: english.body,
      persistent: false,
    );

    await newScheduler().replan(text: english, isRecorded: (_) => false);

    final LocalDay today = LocalDay(2026, 9, 28);
    expect(scheduled(), <Reminder>[
      for (int i = 0; i < 14; i++)
        (
          id: ReminderPlanner.idFor(today.addDays(i)),
          // 20:00 CEST, every day of this window.
          utc: DateTime.utc(2026, 9, 28 + i, 18),
          title: english.title,
          body: english.body,
          persistent: false,
        ),
    ]);
    expect(
      notifications.scheduled.keys,
      isNot(contains(ReminderPlanner.legacyReminderId)),
    );
    expect(
      log.lines.last,
      '[INFO] 2026-09-28 07:00:00.000Z: [NOTIFICATIONS] Planned 14 reminders '
      'at 20:00 Europe/Berlin (from 2026-09-28, persistent: false)',
    );
  });

  test(
    'never schedules while the switch is off: saving a clip no longer '
    'turns on a reminder the user never enabled (v1.7 did, C 5.3 #2)',
    () async {
      stored = off;
      // Left over from before the user turned reminders off.
      await notifications.schedule(
        id: ReminderPlanner.idFor(LocalDay(2026, 9, 29)),
        at: DateTime.utc(2026, 9, 29, 18),
        title: english.title,
        body: english.body,
        persistent: false,
      );

      // What saving today's clip triggers.
      await newScheduler().replan(
        text: english,
        isRecorded: <LocalDay>{LocalDay(2026, 9, 28)}.contains,
      );

      expect(notifications.scheduled, isEmpty);
    },
  );

  test("recording today removes today's reminder, pending or on screen, and "
      'keeps the others (issue #66: a persistent one stayed forever); '
      "opening the app after today's reminder without recording leaves it "
      'alone; overlapping re-plans run one after the other, the last one '
      'winning', () async {
    stored = persistentOn20;
    final ReminderScheduler scheduler = newScheduler();
    final int todayId = ReminderPlanner.idFor(LocalDay(2026, 9, 28));
    await scheduler.replan(text: english, isRecorded: (_) => false);
    expect(notifications.scheduled.keys, contains(todayId));

    clock.advance(const Duration(hours: 12, minutes: 30)); // 21:30, shown
    await scheduler.replan(text: english, isRecorded: (_) => false);

    expect(notifications.shown.map((ScheduledNotification n) => n.id), <int>[
      todayId,
    ]);
    expect(notifications.skipped, isEmpty);

    clock.advance(const Duration(minutes: 30)); // 22:00
    // App start and a save of today's clip, at the same moment.
    await Future.wait(<Future<void>>[
      scheduler.replan(text: english, isRecorded: (_) => false),
      scheduler.replan(
        text: english,
        isRecorded: <LocalDay>{LocalDay(2026, 9, 28)}.contains,
      ),
    ]);

    expect(notifications.scheduled.keys, isNot(contains(todayId)));
    expect(
      notifications.scheduled.keys,
      contains(ReminderPlanner.idFor(LocalDay(2026, 9, 29))),
    );
  });

  test('a language, settings or time-zone change re-plans: in the new '
      'language (v1.7 kept the old one until the next reschedule, C 5.3 '
      '#7), with the stored time and persistence, at 20:00 where the user '
      'is now', () async {
    final ReminderScheduler scheduler = newScheduler();
    await scheduler.replan(text: english, isRecorded: (_) => false);

    const ReminderText portuguese = ReminderText(
      title: 'Ei!',
      body: 'Não se esqueça de gravar 1 segundo do seu dia',
    );
    await scheduler.replan(text: portuguese, isRecorded: (_) => false);

    expect(scheduled(), hasLength(14));
    expect(
      scheduled().map((Reminder r) => (r.title, r.body)),
      everyElement((portuguese.title, portuguese.body)),
    );

    stored = const ReminderSettings(
      enabled: true,
      persistent: true,
      time: (hour: 7, minute: 45),
    );
    await scheduler.replan(text: english, isRecorded: (_) => false);

    // 09:00 now: today's 07:45 has passed, so tomorrow first, and today's
    // old 20:00 reminder (not delivered yet) is gone.
    expect(scheduled().first.utc, DateTime.utc(2026, 9, 29, 5, 45));
    expect(scheduled(), hasLength(13));
    expect(scheduled().map((Reminder r) => r.persistent), everyElement(isTrue));

    stored = on20;
    zone.name = 'America/New_York';
    await scheduler.replan(text: english, isRecorded: (_) => false);

    // 20:00 EDT (UTC-4) on 2026-09-28 in New York.
    expect(scheduled().first.utc, DateTime.utc(2026, 9, 29));
    expect(scheduled(), hasLength(14));
  });

  test('a platform failure is logged, never thrown, and the next re-plan '
      'still runs', () async {
    final _FailingOnceNotificationsGateway failing =
        _FailingOnceNotificationsGateway(clock: clock);
    addTearDown(failing.close);
    notifications = failing;
    final ReminderScheduler scheduler = newScheduler();

    await scheduler.replan(text: english, isRecorded: (_) => false);
    expect(
      log.lines.last,
      startsWith(
        '[ERROR] 2026-09-28 07:00:00.000Z: [NOTIFICATIONS] Could not plan '
        'the reminders',
      ),
    );

    await scheduler.replan(text: english, isRecorded: (_) => false);
    expect(scheduled(), hasLength(14));
  });
}

/// Throws a [PlatformException] from its first `schedule`, like a plugin
/// failure on a device.
class _FailingOnceNotificationsGateway extends DeliveringNotificationsGateway {
  _FailingOnceNotificationsGateway({required super.clock});

  bool _failed = false;

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required bool persistent,
  }) async {
    if (!_failed) {
      _failed = true;
      throw PlatformException(code: 'zonedSchedule');
    }
    await super.schedule(
      id: id,
      at: at,
      title: title,
      body: body,
      persistent: persistent,
    );
  }
}
