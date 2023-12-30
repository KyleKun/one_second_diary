import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/osd_date_time.dart';
import 'constants.dart';
import 'shared_preferences_util.dart';
import 'utils.dart';

class NotificationService {
  final _notificationKey = 'activatedNotification';
  final _persistentKey = 'persistentNotification';
  final _hourKey = 'scheduledTimeHour';
  final _minuteKey = 'scheduledTimeMinute';
  final _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  late NotificationDetails _platformNotificationDetails;
  final NotificationDetails _platformNonPersistentNotificationDetails = const NotificationDetails(
    android: AndroidNotificationDetails(
        'channel id',
        'channel name',
        channelDescription: 'channel description',
        ongoing: false,
        autoCancel: true
    ),
  );
  final NotificationDetails _platformPersistentNotificationDetails = const NotificationDetails(
    android: AndroidNotificationDetails(
        'channel id',
        'channel name',
        channelDescription: 'channel description',
        ongoing: true,
        autoCancel: false
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

  void switchNotification() {
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
    const permission = Permission.notification;
    if (await permission.isPermanentlyDenied) {
      return;
    }

    // request for permission
    final bool hasPermission = await Utils.requestPermission(permission);
    if (hasPermission) {
      /// Save notification on SharedPrefs
      switchNotification();

      Utils.logInfo(
        '[NOTIFICATIONS] - Notifications were enabled',
      );
    }
  }

  Future<void> turnOffNotifications() async {
    Utils.logInfo(
      '[NOTIFICATIONS] - Notifications were disabled',
    );

    /// Cancel notification if switch is OFF
    _flutterLocalNotificationsPlugin.cancelAll();

    /// Save notification on SharedPrefs
    switchNotification();
  }

  Future<void> activatePersistentNotifications() async {
    Utils.logInfo(
      '[NOTIFICATIONS] - Persistent notifications were enabled',
    );
    _platformNotificationDetails = _platformPersistentNotificationDetails;

    /// Save notification on SharedPrefs
    _switchPersistentNotification();
  }

  Future<void> deactivatePersistentNotifications() async {
    Utils.logInfo(
      '[NOTIFICATIONS] - Persistent notifications were disabled',
    );
    _platformNotificationDetails = _platformNonPersistentNotificationDetails;

    /// Save notification on SharedPrefs
    _switchPersistentNotification();
  }

  void scheduleFutureNotifications() async {
    if (!isNotificationActivated()) return;

    int notificationId = getNotificationId();
    final notificationDates = Utils.getDateTimes();

    // remove received notifications from db
    for (int i = 0; i < notificationDates.length; i++) {
      final OSDDateTime notificationDate = notificationDates[i];
      final DateTime dateTime = DateTime(
        notificationDate.year,
        notificationDate.month,
        notificationDate.day,
        notificationDate.hour,
        notificationDate.minute,
      );
      if (dateTime.isBefore(DateTime.now())) {
        notificationDates.removeAt(i);
      }
    }

    // set scheduled time in DateTime format
    late DateTime dateTime;
    if (notificationDates.isEmpty) {
      final TimeOfDay scheduleTime = getScheduledTime();
      final DateTime tomorrowDate = DateTime.now().add(const Duration(days: 1));
      dateTime = DateTime(
        tomorrowDate.year,
        tomorrowDate.month,
        tomorrowDate.day,
        scheduleTime.hour,
        scheduleTime.minute,
      );
    } else {
      final OSDDateTime osdDateTime = notificationDates.last;
      dateTime = DateTime(
        osdDateTime.year,
        osdDateTime.month,
        osdDateTime.day,
        osdDateTime.hour,
        osdDateTime.minute,
      );
      dateTime = dateTime.add(const Duration(days: 1));
    }

    // schedule notifications
    while (notificationDates.length < Constants.scheduleNotificationForDays) {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        'notificationTitle'.tr,
        'notificationBody'.tr,
        tz.TZDateTime.parse(tz.local, dateTime.toString()),
        _platformNotificationDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      notificationDates.add(OSDDateTime(
        year: dateTime.year,
        month: dateTime.month,
        day: dateTime.day,
        hour: dateTime.hour,
        minute: dateTime.minute,
        notificationId: notificationId,
      ));

      // increase day
      dateTime = dateTime.add(const Duration(days: 1));
      notificationId = getNotificationId();
    }

    // saving notification dates in db
    Utils.saveDateTimes(notificationDates);
    Utils.logInfo(
      '[NOTIFICATIONS] - Notifications were scheduled',
    );
  }

  void rescheduleNotifications(int hour, int minute) async {
    if (!isNotificationActivated()) return;

    int notificationId = getNotificationId();

    _flutterLocalNotificationsPlugin.cancelAll();

    // set scheduled time in DateTime format
    final DateTime today = DateTime.now();
    DateTime dateTime = DateTime(
      today.year,
      today.month,
      today.day,
      hour,
      minute,
    );

    final List<OSDDateTime> notificationDates = [];

    // schedule notifications
    while (notificationDates.length < Constants.scheduleNotificationForDays) {
      if (dateTime.isAfter(DateTime.now())) {
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          notificationId,
          'notificationTitle'.tr,
          'notificationBody'.tr,
          tz.TZDateTime.parse(tz.local, dateTime.toString()),
          _platformNotificationDetails,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        notificationDates.add(OSDDateTime(
          year: dateTime.year,
          month: dateTime.month,
          day: dateTime.day,
          hour: dateTime.hour,
          minute: dateTime.minute,
          notificationId: notificationId,
        ));
        notificationId = getNotificationId();
      }

      // increase day
      dateTime = dateTime.add(const Duration(days: 1));
    }

    // saving notification dates in db
    Utils.saveDateTimes(notificationDates);
    Utils.logInfo(
      '[NOTIFICATIONS] - Notifications were rescheduled',
    );
  }

  void cancelTodayNotification() async {
    final List<OSDDateTime> notificationDates = Utils.getDateTimes();

    // cancel notification
    if (notificationDates.isNotEmpty) {
      final first = notificationDates.first;
      await _flutterLocalNotificationsPlugin.cancel(first.notificationId);
      notificationDates.remove(first);
      Utils.saveDateTimes(notificationDates);
    }

    Utils.logInfo(
      '[NOTIFICATIONS] - Notification was canceled for today',
    );
  }

  void scheduleTodayNotification() async {
    final notificationDates = Utils.getDateTimes();
    final int notificationId = getNotificationId();

    final TimeOfDay scheduleTime = getScheduledTime();
    final DateTime todayDate = DateTime.now();
    final dateTime = DateTime(
      todayDate.year,
      todayDate.month,
      todayDate.day,
      scheduleTime.hour,
      scheduleTime.minute,
    );

    if (dateTime.isBefore(DateTime.now())) return;

    // schedule notification
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      'notificationTitle'.tr,
      'notificationBody'.tr,
      tz.TZDateTime.parse(tz.local, dateTime.toString()),
      _platformNotificationDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    notificationDates.insert(0, OSDDateTime(
      year: dateTime.year,
      month: dateTime.month,
      day: dateTime.day,
      hour: dateTime.hour,
      minute: dateTime.minute,
      notificationId: notificationId,
    ));

    // saving notification dates in db
    Utils.saveDateTimes(notificationDates);
    Utils.logInfo(
      '[NOTIFICATIONS] - Notification was scheduled for today',
    );
  }

  int getNotificationId() {
    return Random().nextInt(100000);
  }

  Future<void> showTestNotification() async {
    await _flutterLocalNotificationsPlugin.show(
      0,
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
