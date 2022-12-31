import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../../routes/app_pages.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/notification_service.dart';
import '../../../../utils/shared_preferences_util.dart';
import '../../../../utils/theme.dart';
import '../../../../utils/utils.dart';

class SwitchNotificationsComponent extends StatefulWidget {
  @override
  _SwitchNotificationsComponentState createState() =>
      _SwitchNotificationsComponentState();
}

class _SwitchNotificationsComponentState
    extends State<SwitchNotificationsComponent> {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  final int notificationId = 1;

  TimeOfDay scheduledTimeOfDay = const TimeOfDay(hour: 20, minute: 00);

  @override
  void initState() {
    super.initState();

    // Sets the default values for scheduled time
    getScheduledTime();

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

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  @override
  void dispose() {
    super.dispose();
  }

  final platformNotificationDetails = const NotificationDetails(
    android: AndroidNotificationDetails(
      'channel id',
      'channel name',
      channelDescription: 'channel description',
    ),
  );

  // Checks for the scheduled time and sets it to a value in shared prefs
  void getScheduledTime() {
    final int hour = SharedPrefsUtil.getInt('scheduledTimeHour') ?? 20;
    final int minute = SharedPrefsUtil.getInt('scheduledTimeMinute') ?? 00;
    scheduledTimeOfDay = TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> scheduleNotification() async {
    final now = DateTime.now();

    // sets the scheduled time in DateTime format
    final String setTime = DateTime(
      now.year,
      now.month,
      now.day,
      scheduledTimeOfDay.hour,
      scheduledTimeOfDay.minute,
    ).toString();

    Utils.logInfo('[NOTIFICATIONS] - Scheduled with setTime=$setTime');

    /// Schedule notification
    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      'notificationTitle'.tr,
      'notificationBody'.tr,
      tz.TZDateTime.parse(tz.local, setTime),
      platformNotificationDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
      // Allow notification to be shown daily
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> showTestNotification() async {
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      'test'.tr,
      'test'.tr,
      platformNotificationDetails,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => Get.toNamed(Routes.NOTIFICATION),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'enableNotifications'.tr,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.045,
                  ),
                ),
                ValueBuilder<bool?>(
                  initialValue: NotificationService().isNotificationActivated(),
                  builder: (isChecked, updateFn) => Switch(
                    value: isChecked!,
                    onChanged: (value) async {
                      /// Save notification on SharedPrefs
                      NotificationService().switchNotification();

                      /// Update switch value
                      updateFn(NotificationService().isNotificationActivated());

                      if (NotificationService().isNotificationActivated()) {
                        Utils.logInfo(
                          '[NOTIFICATIONS] - Notifications were enabled',
                        );

                        /// Schedule notification if switch in ON
                        await Utils.requestPermission(Permission.notification);
                        await scheduleNotification();
                      } else {
                        Utils.logInfo(
                          '[NOTIFICATIONS] - Notifications were disabled',
                        );

                        /// Cancel notification if switch is OFF
                        flutterLocalNotificationsPlugin.cancelAll();
                      }

                      // Set state should be called for the test widget to revalidate the notification toggle
                      setState(() {});
                    },
                    activeTrackColor: AppColors.mainColor.withOpacity(0.4),
                    activeColor: AppColors.mainColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        if (NotificationService().isNotificationActivated()) ...{
          InkWell(
            onTap: showTestNotification,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'test'.tr,
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width * 0.045,
                    ),
                  ),
                  IconButton(
                    onPressed: showTestNotification,
                    splashRadius: 24,
                    icon: const Icon(
                      Icons.play_arrow,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
        },
        InkWell(
          onTap: () async {
            final TimeOfDay? newTimeOfDay = await showTimePicker(
              context: context,
              initialTime: scheduledTimeOfDay,
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ThemeService().isDarkTheme()
                      ? const ColorScheme.dark(
                          primary: AppColors.mainColor,
                          onSurface: AppColors.light,
                        )
                      : const ColorScheme.light(
                          primary: AppColors.dark,
                          onSurface: AppColors.dark,
                        ),
                ),
                child: child!,
              ),
            );

            /// If the 'Cancel' button is pressed or the user quits without setting a time, `newTime` becomes null
            if (newTimeOfDay == null) return;

            setState(() {
              scheduledTimeOfDay = newTimeOfDay;
              SharedPrefsUtil.putInt('scheduledTimeHour', newTimeOfDay.hour);
              SharedPrefsUtil.putInt(
                  'scheduledTimeMinute', newTimeOfDay.minute);
            });

            await scheduleNotification();
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'scheduleTime'.tr,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.045,
                  ),
                ),
                Text(
                  '${scheduledTimeOfDay.format(context)}',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.045,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}
