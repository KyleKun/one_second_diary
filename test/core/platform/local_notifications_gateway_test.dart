import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/local_notifications_gateway.dart';
import 'package:one_second_diary/core/platform/notification_channel_text.dart';
import 'package:one_second_diary/core/platform/notification_tap.dart';
import 'package:one_second_diary/core/time/local_time_zone.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../support/support.dart';
import '../../support/track_1d/fake_notifications_channel.dart';
import '../../support/track_1d/fake_time_zone_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryLogSink log;
  late FakeClock clock;

  const NotificationChannelText english = NotificationChannelText(
    name: 'Daily reminder',
    description: 'Your daily reminder to record one second of your day',
  );
  const NotificationChannelText german = NotificationChannelText(
    name: 'Tägliche Erinnerung',
    description: 'Deine tägliche Erinnerung',
  );

  setUp(() {
    log = MemoryLogSink();
    clock = FakeClock(DateTime(2030, 1, 10, 9));
  });

  LocalNotificationsGateway gatewayOn(FakeNotificationsChannel channel) {
    channel.install();
    return LocalNotificationsGateway(
      plugin: FlutterLocalNotificationsPlugin(),
      timeZone: LocalTimeZone(
        gateway: FakeTimeZoneGateway('Europe/Berlin'),
        logger: memoryLogger(log),
      ),
      clock: clock,
      logger: memoryLogger(log, clock: clock),
      androidSmallIcon: '@mipmap/ic_launcher',
    );
  }

  group('initialize', () {
    test('on iOS never asks for permission (v1.7 asked at first launch) and '
        'shows reminders while the app is open', () async {
      final FakeNotificationsChannel channel = FakeNotificationsChannel(
        platform: TargetPlatform.iOS,
      );

      await gatewayOn(channel).initialize(channel: english);

      expect(
        channel.argumentsOf('initialize'),
        allOf(
          containsPair('requestAlertPermission', false),
          containsPair('requestSoundPermission', false),
          containsPair('requestBadgePermission', false),
          containsPair('requestProvisionalPermission', false),
          containsPair('defaultPresentBanner', true),
          containsPair('defaultPresentList', true),
          containsPair('defaultPresentSound', true),
        ),
      );
    });

    // Android updates an existing channel's name and description when it is
    // created again with the same id, and keeps the user's settings.
    test("on Android keeps v1.7's channel id, so users keep their "
        "per-channel settings, names it in the app's language and renames "
        'it in place for a new language', () async {
      final FakeNotificationsChannel channel = FakeNotificationsChannel();
      final LocalNotificationsGateway gateway = gatewayOn(channel);

      await gateway.initialize(channel: english);

      expect(tz.local.name, 'Europe/Berlin');
      expect(
        channel.argumentsOf('initialize'),
        containsPair('defaultIcon', '@mipmap/ic_launcher'),
      );
      expect(
        channel.argumentsOf('createNotificationChannel'),
        allOf(
          containsPair('id', 'channel id'),
          containsPair('name', 'Daily reminder'),
          containsPair(
            'description',
            'Your daily reminder to record one second of your day',
          ),
        ),
      );

      await gateway.updateChannel(german);

      expect(
        channel.callsTo('createNotificationChannel').last.arguments,
        allOf(
          containsPair('id', 'channel id'),
          containsPair('name', 'Tägliche Erinnerung'),
          containsPair('description', 'Deine tägliche Erinnerung'),
        ),
      );
    });
  });

  group('schedule', () {
    late FakeNotificationsChannel channel;
    late LocalNotificationsGateway gateway;

    setUp(() async {
      channel = FakeNotificationsChannel();
      gateway = gatewayOn(channel);
      await gateway.initialize(channel: english);
    });

    test('schedules one inexact notification (decision D12) at the local '
        "wall time, in v1.7's channel, without a daily repeat", () async {
      await gateway.schedule(
        id: 3,
        at: DateTime.utc(2030, 1, 12, 19), // 20:00 in Berlin
        title: 'Heyy!',
        body: 'Do not forget to record 1 second of your day',
        persistent: false,
      );

      final Map<Object?, Object?> arguments = channel.argumentsOf(
        'zonedSchedule',
      );
      expect(arguments['id'], 3);
      expect(arguments['title'], 'Heyy!');
      expect(arguments['body'], 'Do not forget to record 1 second of your day');
      expect(arguments['timeZoneName'], 'Europe/Berlin');
      expect(arguments['scheduledDateTime'], '2030-01-12T20:00:00');
      expect(arguments.containsKey('matchDateTimeComponents'), isFalse);
      expect(
        arguments['platformSpecifics'],
        allOf(
          containsPair('scheduleMode', 'inexactAllowWhileIdle'),
          containsPair('channelId', 'channel id'),
          containsPair('channelName', 'Daily reminder'),
        ),
      );
    });

    // A persistent reminder cannot be swiped away, so every reminder times
    // out before the next day's one.
    test('a persistent reminder is ongoing and survives a tap, a normal one '
        'goes away when tapped (v1.7), and both leave the shade after 23 '
        'hours', () async {
      await gateway.schedule(
        id: 3,
        at: DateTime.utc(2030, 1, 12, 19),
        title: 'Heyy!',
        body: 'body',
        persistent: true,
      );
      await gateway.schedule(
        id: 4,
        at: DateTime.utc(2030, 1, 13, 19),
        title: 'Heyy!',
        body: 'body',
        persistent: false,
      );

      final List<Object?> details = <Object?>[
        for (final MethodCall call in channel.callsTo('zonedSchedule'))
          (call.arguments as Map<Object?, Object?>)['platformSpecifics'],
      ];
      final Matcher dayLong = containsPair(
        'timeoutAfter',
        const Duration(hours: 23).inMilliseconds,
      );
      expect(
        details.first,
        allOf(
          containsPair('ongoing', true),
          containsPair('autoCancel', false),
          dayLong,
        ),
      );
      expect(
        details.last,
        allOf(
          containsPair('ongoing', false),
          containsPair('autoCancel', true),
          dayLong,
        ),
      );
    });

    // The plugin reads the real clock a moment after the gateway's check,
    // and throws "must be a date in the future" itself.
    test('an instant that is not in the future, by the gateway or by the '
        'plugin, is skipped and logged, never thrown, so the rest of a plan '
        'still gets scheduled', () async {
      await gateway.schedule(
        id: 3,
        at: clock.now(),
        title: 'Heyy!',
        body: 'body',
        persistent: false,
      );
      expect(
        log.lines.last,
        startsWith(
          '[WARNING] 2030-01-10 09:00:00.000: [NOTIFICATIONS] Skipped '
          'reminder 3: its time has passed',
        ),
      );

      // The gateway's clock says the instant is ahead; the plugin's real
      // clock says it has passed.
      clock.setNow(DateTime(2000, 1, 10, 9));
      await gateway.schedule(
        id: 4,
        at: DateTime(2000, 1, 12, 20),
        title: 'Heyy!',
        body: 'body',
        persistent: false,
      );

      expect(channel.callsTo('zonedSchedule'), isEmpty);
      expect(
        log.lines.last,
        contains('Skipped reminder 4: its time has passed'),
      );
    });
  });

  test('a tap reaches the taps stream: the one that launched the app '
      'through initialize, to the listeners subscribed before it, then each '
      'tap while the app runs', () async {
    final FakeNotificationsChannel channel = FakeNotificationsChannel()
      ..launchDetails = <String, Object?>{
        'notificationLaunchedApp': true,
        'notificationResponse': <String, Object?>{
          'notificationId': 7,
          'notificationResponseType': 0,
          'payload': '',
        },
      };
    final LocalNotificationsGateway gateway = gatewayOn(channel);
    final List<NotificationTap> taps = <NotificationTap>[];
    final StreamSubscription<NotificationTap> subscription = gateway.taps
        .listen(taps.add);
    addTearDown(subscription.cancel);

    await gateway.initialize(channel: english);
    await pumpEventQueue();
    await channel.tapFromOs(6);
    await pumpEventQueue();

    expect(taps, const <NotificationTap>[
      NotificationTap(id: 7),
      NotificationTap(id: 6),
    ]);
  });
}
