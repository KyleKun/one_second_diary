import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/notification_channel_text.dart';
import 'package:one_second_diary/core/platform/notification_tap.dart';
import 'package:one_second_diary/core/platform/notifications_gateway.dart';
import 'package:one_second_diary/core/platform/pending_notification.dart';
import 'package:one_second_diary/core/time/local_time_zone.dart';
import 'package:timezone/timezone.dart' as tz;

/// [NotificationsGateway] over `flutter_local_notifications`. What to
/// schedule and when is `ReminderScheduler`'s job.
///
/// - No permission prompt at start-up: the Darwin `request*` flags are off,
///   and permission goes through `PermissionGateway` when the user turns
///   reminders on.
/// - One-shot, inexact notifications (`inexactAllowWhileIdle`): asking for
///   exact alarms without the permission throws on Android 12+.
/// - Taps are reported ([taps]), including the one that launched the app.
/// - iOS shows reminders while the app is open (the `defaultPresent*`
///   flags; the AppDelegate must also set the notification-center delegate).
final class LocalNotificationsGateway implements NotificationsGateway {
  /// [androidSmallIcon] is the status-bar icon resource. Android masks a
  /// full-colour icon (`@mipmap/ic_launcher`) to a white blob, so the DI
  /// passes the monochrome `reminderSmallIcon`.
  LocalNotificationsGateway({
    required this._plugin,
    required this._timeZone,
    required this._clock,
    required this._logger,
    required this._androidSmallIcon,
  });

  /// The Android channel. Users keep their per-channel settings (sound,
  /// importance, blocked) only while the id stays the same, so the id never
  /// changes. Its name and description come in the app's language
  /// ([NotificationChannelText]): creating the channel again with the same
  /// id updates both in Android's settings and keeps the user's choices.
  static const String channelId = 'channel id';

  /// How long a reminder stays in the shade. There is one id per day, and
  /// without an expiry the reminders of days the app was not opened would
  /// pile up, persistent ones included, which cannot be swiped away. 23
  /// hours takes each one away before the next day's arrives. Android only.
  static const Duration expireAfter = Duration(hours: 23);

  static const String _tag = 'NOTIFICATIONS';

  final FlutterLocalNotificationsPlugin _plugin;
  final LocalTimeZone _timeZone;
  final Clock _clock;
  final AppLogger _logger;
  final String _androidSmallIcon;

  final StreamController<NotificationTap> _taps =
      StreamController<NotificationTap>.broadcast();

  /// The channel's name and description as last set; [schedule] passes them
  /// too, in case the user deleted the channel meanwhile.
  late NotificationChannelText _channel;

  /// Also creates the Android channel again (see [channelId]) and, when a
  /// reminder tap launched the app, emits that tap on [taps]: listen before
  /// calling this.
  @override
  Future<void> initialize({required NotificationChannelText channel}) async {
    _channel = channel;
    await _timeZone.resolve();
    await _plugin.initialize(
      settings: InitializationSettings(
        android: AndroidInitializationSettings(_androidSmallIcon),
        iOS: const DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onResponse,
    );
    await _createChannel();
    final NotificationAppLaunchDetails? launch = await _plugin
        .getNotificationAppLaunchDetails();
    final NotificationResponse? response = launch?.notificationResponse;
    if (launch != null && launch.didNotificationLaunchApp && response != null) {
      _onResponse(response);
    }
  }

  @override
  Future<void> updateChannel(NotificationChannelText channel) {
    _channel = channel;
    return _createChannel();
  }

  Future<void> _createChannel() async => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        AndroidNotificationChannel(
          channelId,
          _channel.name,
          description: _channel.description,
        ),
      );

  /// Converts [at] to `tz.local` (set up by [initialize]); a one-shot keeps
  /// its instant whatever the zone.
  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required bool persistent,
  }) async {
    if (!at.isAfter(_clock.now())) {
      _logSkip(id, at);
      return;
    }
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channel.name,
            channelDescription: _channel.description,
            ongoing: persistent,
            autoCancel: !persistent,
            timeoutAfter: expireAfter.inMilliseconds,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on ArgumentError catch (error) {
      // The plugin's own future check, with the real clock, a moment later.
      if (error.name != 'scheduledDate') rethrow;
      _logSkip(id, at);
    }
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<List<PendingNotification>> pending() async => <PendingNotification>[
    for (final PendingNotificationRequest request
        in await _plugin.pendingNotificationRequests())
      PendingNotification(
        id: request.id,
        title: request.title,
        body: request.body,
      ),
  ];

  @override
  Stream<NotificationTap> get taps => _taps.stream;

  void _onResponse(NotificationResponse response) =>
      _taps.add(NotificationTap(id: response.id));

  void _logSkip(int id, DateTime at) =>
      _logger.warning(_tag, 'Skipped reminder $id: its time has passed ($at)');
}
