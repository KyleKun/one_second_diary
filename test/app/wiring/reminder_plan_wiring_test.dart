import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/wiring/active_profile_clips.dart';
import 'package:one_second_diary/app/wiring/reminder_plan_wiring.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/notification_channel_text.dart';
import 'package:one_second_diary/core/platform/notification_tap.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/local_time_zone.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/reminders/data/reminder_scheduler.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_planner.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_settings.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_text.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../shared/fakes/clip_index_fixture.dart';
import '../../shared/fakes/fake_clip_repository.dart';
import '../../shared/fakes/fake_profiles_repository.dart';
import '../../support/support.dart';
import '../../support/track_1d/fake_time_zone_gateway.dart';

/// Delivers the tap that launched the app at the end of `initialize()`, and
/// refuses to schedule before it, as the real gateway does (it sets up the
/// local time zone there). While [initializing] is set, `initialize()` waits
/// for it.
class _PluginGateway extends FakeNotificationsGateway {
  _PluginGateway({required super.clock});

  Completer<void>? initializing;

  @override
  Future<void> initialize({required NotificationChannelText channel}) async {
    await initializing?.future;
    await super.initialize(channel: channel);
    tap(7);
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required bool persistent,
  }) {
    if (!initialized) throw StateError('The plugin is not initialised');
    return super.schedule(
      id: id,
      at: at,
      title: title,
      body: body,
      persistent: persistent,
    );
  }
}

const ProfileKey work = ProfileKey('Work');

/// The clock's day, and the next one.
final LocalDay today = LocalDay(2024, 1, 5);
final LocalDay tomorrow = LocalDay(2024, 1, 6);

void main() {
  late FakeClock clock;
  late MemoryLogSink sink;
  late AppLogger logger;
  late _PluginGateway notifications;
  late ReminderScheduler reminders;
  late SettingsRepository settings;
  late FakeProfilesRepository profiles;
  late FakeClipRepository clips;
  late List<NotificationTap> taps;
  late ReminderText text;
  late NotificationChannelText channelText;

  setUp(() async {
    clock = FakeClock(DateTime(2024, 1, 5, 10));
    sink = MemoryLogSink();
    logger = memoryLogger(sink, clock: clock);
    notifications = _PluginGateway(clock: clock);
    settings = SettingsRepository(
      prefs: await openLegacyPrefs(
        legacyPrefs(extra: <String, Object>{'activatedNotification': true}),
      ),
    );
    // The real scheduler, planning at 20:00 in UTC (every test zone's
    // 10:00 on 5 January is earlier that day).
    reminders = ReminderScheduler(
      notifications: notifications,
      readSettings: () => ReminderSettings(
        enabled: settings.remindersEnabled.value,
        persistent: settings.persistentReminder.value,
        time: settings.reminderTime.value,
      ),
      timeZone: LocalTimeZone(
        gateway: FakeTimeZoneGateway('UTC'),
        logger: logger,
      ),
      clock: clock,
      logger: logger,
    );
    profiles = FakeProfilesRepository();
    clips = FakeClipRepository();
    taps = <NotificationTap>[];
    text = const ReminderText(title: 'Record', body: 'Your second');
    channelText = const NotificationChannelText(
      name: 'Daily reminder',
      description: 'Your daily second',
    );
    addTearDown(() async {
      await notifications.close();
      await profiles.close();
      await clips.close();
    });
  });

  /// The instant of [notification], in UTC.
  DateTime utcOf(ScheduledNotification notification) =>
      DateTime.fromMillisecondsSinceEpoch(
        notification.at.millisecondsSinceEpoch,
        isUtc: true,
      );

  /// Whether a reminder is scheduled for [day].
  bool remindsOn(LocalDay day) {
    final ScheduledNotification? reminder =
        notifications.scheduled[ReminderPlanner.idFor(day)];
    if (reminder == null) return false;
    final DateTime utc = utcOf(reminder);
    return LocalDay(utc.year, utc.month, utc.day) == day;
  }

  Iterable<String> scheduledTitles() => notifications.scheduled.values.map(
    (ScheduledNotification reminder) => reminder.title,
  );

  ReminderPlanWiring wiring() {
    final ReminderPlanWiring wiring = ReminderPlanWiring(
      notifications: notifications,
      reminders: reminders,
      reminderText: () => text,
      channelText: () => channelText,
      settings: settings,
      activeClips: ActiveProfileClips(profiles: profiles, clips: clips),
      clock: clock,
      logger: logger,
      onNotificationTap: taps.add,
    );
    addTearDown(wiring.dispose);
    return wiring;
  }

  group('notifications', () {
    test('hands the tap that launched the app to the tap handler', () async {
      await wiring().start();
      await pumpEventQueue();

      expect(taps, <NotificationTap>[const NotificationTap(id: 7)]);
    });

    test('plans the reminders once the plugin is initialised, in the '
        'current language', () async {
      await wiring().start();
      await pumpEventQueue();

      expect(remindsOn(today), isTrue);
      expect(scheduledTitles(), everyElement(text.title));
    });

    // LocalNotificationsGateway schedules only after initialize().
    test('plans nothing before the plugin is initialised, then plans the '
        'days already read', () async {
      clips.publish(clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[today]));
      final Completer<void> initializing = notifications.initializing =
          Completer<void>();

      final Future<void> started = wiring().start();
      await pumpEventQueue();
      expect(notifications.scheduled, isEmpty);
      expect(sink.lines, isNot(contains(contains('Could not plan'))));

      initializing.complete();
      await started;
      await pumpEventQueue();

      expect(sink.lines, isNot(contains(contains('Could not plan'))));
      expect(remindsOn(today), isFalse, reason: 'today is recorded');
      expect(remindsOn(tomorrow), isTrue);
    });

    test('follows the reminder settings', () async {
      await settings.remindersEnabled.set(false);
      await wiring().start();
      await pumpEventQueue();
      expect(notifications.scheduled, isEmpty);

      await settings.remindersEnabled.set(true);
      await pumpEventQueue();
      expect(remindsOn(tomorrow), isTrue);

      await settings.persistentReminder.set(true);
      await pumpEventQueue();
      expect(
        notifications.scheduled.values.map(
          (ScheduledNotification reminder) => reminder.persistent,
        ),
        everyElement(isTrue),
      );

      await settings.reminderTime.set((hour: 21, minute: 30));
      await pumpEventQueue();
      expect(
        utcOf(notifications.scheduled[ReminderPlanner.idFor(tomorrow)]!),
        DateTime.utc(2024, 1, 6, 21, 30),
      );
    });

    test('re-plans in the new language once it is applied', () async {
      final ReminderPlanWiring subject = wiring();
      await subject.start();

      text = const ReminderText(title: 'Aufnehmen', body: 'Deine Sekunde');
      subject.localeChanged();
      await pumpEventQueue();

      expect(scheduledTitles(), everyElement('Aufnehmen'));
    });

    test("names the Android channel in the app's language", () async {
      await wiring().start();

      expect(notifications.channel, channelText);
    });

    test(
      'renames the Android channel once a new language is applied',
      () async {
        final ReminderPlanWiring subject = wiring();
        await subject.start();

        channelText = const NotificationChannelText(
          name: 'Tägliche Erinnerung',
          description: 'Deine tägliche Sekunde',
        );
        subject.localeChanged();
        await pumpEventQueue();

        expect(notifications.channel, channelText);
      },
    );
  });

  group('the recorded days', () {
    setUp(() async {
      await wiring().start();
      await pumpEventQueue();
    });

    test('are planned again once the active profile is first read', () async {
      expect(remindsOn(tomorrow), isTrue, reason: 'nothing read yet');

      clips.publish(
        clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[tomorrow]),
      );
      await pumpEventQueue();

      expect(remindsOn(tomorrow), isFalse);
      expect(remindsOn(LocalDay(2024, 1, 7)), isTrue);
    });

    test('are planned again when recording today', () async {
      clips.publish(
        clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[
          LocalDay(2024, 1, 3),
        ]),
      );
      await pumpEventQueue();
      expect(remindsOn(today), isTrue);

      clips.publish(
        clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[
          LocalDay(2024, 1, 3),
          today,
        ]),
      );
      await pumpEventQueue();

      expect(remindsOn(today), isFalse);
    });

    // Only the next 14 days are planned (ReminderPlanner.windowDays).
    test('stay as planned when only a past day changes', () async {
      clips.publish(
        clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[
          LocalDay(2024, 1, 3),
          tomorrow,
        ]),
      );
      await pumpEventQueue();
      final Map<int, ScheduledNotification> planned =
          Map<int, ScheduledNotification>.of(notifications.scheduled);

      clips.publish(
        clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[
          LocalDay(2024, 1, 2),
          LocalDay(2024, 1, 3),
          tomorrow,
        ]),
      );
      await pumpEventQueue();

      expect(notifications.scheduled, planned);
    });

    test('ignore the other profiles', () async {
      clips.publish(clipIndexOf(work, <LocalDay>[today]));
      await pumpEventQueue();

      expect(remindsOn(today), isTrue);
    });
  });

  test('a profile switch plans the days of the new active profile', () async {
    profiles = FakeProfilesRepository(
      profiles: <Profile>[
        testProfile(),
        testProfile(key: work),
      ],
    );
    await wiring().start();
    clips
      ..publish(
        clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[
          LocalDay(2024, 1, 3),
        ]),
      )
      ..publish(
        clipIndexOf(work, <LocalDay>[
          LocalDay(2024, 1, 1),
          LocalDay(2024, 1, 2),
          tomorrow,
        ]),
      );
    await pumpEventQueue();
    expect(remindsOn(tomorrow), isTrue);

    await profiles.activate(work);
    await pumpEventQueue();

    expect(remindsOn(tomorrow), isFalse, reason: 'Work recorded it');
    expect(remindsOn(today), isTrue);
    // Then it follows the new profile's recordings.
    clips.publish(
      clipIndexOf(work, <LocalDay>[
        LocalDay(2024, 1, 1),
        LocalDay(2024, 1, 2),
        today,
        tomorrow,
      ]),
    );
    await pumpEventQueue();
    expect(remindsOn(today), isFalse);
  });

  test('stops following everything once disposed', () async {
    await settings.remindersEnabled.set(false);
    final ReminderPlanWiring subject = wiring();
    await subject.start();
    await pumpEventQueue();

    await subject.dispose();
    clips.publish(clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[today]));
    await settings.remindersEnabled.set(true);
    notifications.tap(8);
    await pumpEventQueue();

    expect(notifications.scheduled, isEmpty, reason: 'nothing re-planned');
    expect(taps, <NotificationTap>[const NotificationTap(id: 7)]);
  });
}
