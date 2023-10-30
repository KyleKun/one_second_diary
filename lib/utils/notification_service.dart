import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'constants.dart';
import 'shared_preferences_util.dart';
import 'utils.dart';

class NotificationService {
  final _notificationKey = 'activatedNotification';
  final _persistentKey = 'persistentNotification';
  final _hourKey = 'scheduledTimeHour';
  final _minuteKey = 'scheduledTimeMinute';
  final int _notificationId = 1;
  final _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  late NotificationDetails _platformNotificationDetails;
  final NotificationDetails _platformNonPersistentNotificationDetails = const NotificationDetails(
    android: AndroidNotificationDetails(
        'channel id',
        'channel name',
        channelDescription: 'channel description',
        ongoing: false
    ),
  );
  final NotificationDetails _platformPersistentNotificationDetails = const NotificationDetails(
    android: AndroidNotificationDetails(
        'channel id',
        'channel name',
        channelDescription: 'channel description',
        ongoing: true
    ),
  );

  NotificationService(){
    if(isPersistentNotificationActivated())
      _platformNotificationDetails = _platformPersistentNotificationDetails;
    else
      _platformNotificationDetails = _platformNonPersistentNotificationDetails;

    /// Initializing notification settings
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidInitializationSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInitializationSettings =
    DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Notification is deactivated by default
  bool isNotificationActivated() => SharedPrefsUtil.getBool(_notificationKey) ?? false;
  bool isPersistentNotificationActivated() => SharedPrefsUtil.getBool(_persistentKey) ?? false;

  // Checks for the scheduled time and sets it to a value in shared prefs
  TimeOfDay getScheduledTime() {
    final int hour = SharedPrefsUtil.getInt(_hourKey) ?? 20;
    final int minute = SharedPrefsUtil.getInt(_minuteKey) ?? 00;
    return TimeOfDay(hour: hour, minute: minute);
  }

  void _switchNotification() {
    SharedPrefsUtil.putBool(_notificationKey, !isNotificationActivated());
  }

  void _switchPersistentNotification() {
    SharedPrefsUtil.putBool(_persistentKey, !isPersistentNotificationActivated());
  }

  void setScheduledTime(int hour, int minute) {
    SharedPrefsUtil.putInt(_hourKey, hour);
    SharedPrefsUtil.putInt(_minuteKey, minute);
  }

  Future<void> turnOnNotifications() async {
    Utils.logInfo(
      '[NOTIFICATIONS] - Notifications were enabled',
    );

    /// Schedule notification if switch in ON
    await Utils.requestPermission(Permission.notification);

    /// Save notification on SharedPrefs
    _switchNotification();
  }

  Future<void> turnOffNotifications() async {
    Utils.logInfo(
      '[NOTIFICATIONS] - Notifications were disabled',
    );

    /// Cancel notification if switch is OFF
    _flutterLocalNotificationsPlugin.cancelAll();

    /// Save notification on SharedPrefs
    _switchNotification();
  }

  Future<void> activatePersistentNotifications() async {
    Utils.logInfo(
      '[NOTIFICATIONS] - Persistent notifications were enabled',
    );
    _platformNotificationDetails = _platformPersistentNotificationDetails;

    /// Save notification on SharedPrefs
    _switchPersistentNotification();
  }

  Future<void> unactivatePersistentNotifications() async {
    Utils.logInfo(
      '[NOTIFICATIONS] - Persistent notifications were disabled',
    );
    _platformNotificationDetails = _platformNonPersistentNotificationDetails;

    /// Save notification on SharedPrefs
    _switchPersistentNotification();
  }

  Future<void> scheduleNotification(int hour, int minute) async {
    _flutterLocalNotificationsPlugin.cancelAll();
    final now = DateTime.now();

    // sets the scheduled time in DateTime format
    final String setTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).toString();

    Utils.logInfo('[NOTIFICATIONS] - Scheduled with setTime=$setTime');

    /// Schedule notification
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      _notificationId,
      'notificationTitle'.tr,
      'notificationBody'.tr,
      tz.TZDateTime.parse(tz.local, setTime),
      _platformNotificationDetails,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // Allow notification to be shown daily
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> showTestNotification() async {
    await _flutterLocalNotificationsPlugin.show(
      _notificationId,
      'test'.tr,
      'test'.tr,
      _platformNotificationDetails,
    );

    // Feedback to the user that the notification was called
    await Fluttertoast.showToast(
      msg: 'done'.tr,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: AppColors.dark,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
}
