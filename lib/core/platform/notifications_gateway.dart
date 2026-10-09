import 'package:one_second_diary/core/platform/notification_channel_text.dart';
import 'package:one_second_diary/core/platform/notification_tap.dart';
import 'package:one_second_diary/core/platform/pending_notification.dart';

/// Local notifications (`flutter_local_notifications` + `timezone` +
/// `flutter_timezone`).
///
/// The implementation keeps the Android channel id `'channel id'` (another
/// id would give users a second channel and lose their per-channel
/// settings). The channel's name and description are passed in the app's
/// language ([NotificationChannelText]); Android updates them in place.
/// Scheduling is inexact (`inexactAllowWhileIdle`). What to schedule and
/// when is decided above this boundary (`ReminderPlanner`).
///
/// Permission is not asked here: the one path is `PermissionGateway` with
/// `AppPermission.notifications`, which also reports a blocked permission.
abstract interface class NotificationsGateway {
  /// Sets up the plugin, the local time zone and the Android channel, named
  /// by [channel]. Never prompts for permission (iOS asks only when
  /// reminders are turned on). Call once, after the first frame.
  Future<void> initialize({required NotificationChannelText channel});

  /// Renames the Android channel to [channel] (the app language changed).
  /// Android keeps the user's settings for it; nothing happens on iOS. Call
  /// after [initialize].
  Future<void> updateChannel(NotificationChannelText channel);

  /// Schedules notification [id] at the instant [at] (converted to the local
  /// time zone). A [persistent] notification is ongoing and not auto-cancelled
  /// (Android only). Replaces any pending notification with the same [id].
  ///
  /// An [at] not after the current time (the injected `Clock`) is SKIPPED and
  /// logged, never thrown, so one stale instant cannot abort a plan. The plugin
  /// throws `ArgumentError` and reads the real clock later, so the implementation
  /// checks first AND treats that error as a skip.
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required bool persistent,
  });

  /// Cancels notification [id], pending or shown.
  Future<void> cancel(int id);

  /// Cancels every notification of the app.
  Future<void> cancelAll();

  /// The notifications still waiting to be shown.
  Future<List<PendingNotification>> pending();

  /// Taps on the app's notifications while it is running (a broadcast
  /// stream). It also carries the tap that launched the app, emitted at the
  /// end of [initialize]: subscribe before calling it, or that tap is lost.
  Stream<NotificationTap> get taps;
}
