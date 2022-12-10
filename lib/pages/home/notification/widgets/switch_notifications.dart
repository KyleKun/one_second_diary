import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  _SwitchNotificationsComponentState createState() => _SwitchNotificationsComponentState();
}

class _SwitchNotificationsComponentState extends State<SwitchNotificationsComponent> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

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

    const InitializationSettings initializationSettings = InitializationSettings(
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
    /// Get current hour
    final hour = DateTime.now().hour;

    /// Since there isn't a way to choose the best time to display, it will be shown around 18pm
    const int defaultNotificationHour = 18;

    /// Difference between current hour and 12am to calculate scheduling
    int difference = 0;

    /// Final hour distance that notification will be shown
    int notificationHour = 0;

    if (hour >= defaultNotificationHour) {
      difference = hour - defaultNotificationHour;
      notificationHour = 24 - difference;
    } else {
      difference = defaultNotificationHour - hour;
      notificationHour = difference;
    }

    // print('notification will be shown in: $notificationHour hours from now');

    /// Schedule notification
    flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      'notificationTitle'.tr,
      'notificationBody'.tr,
      tz.TZDateTime.now(tz.local).add(Duration(hours: notificationHour)),
      // tz.TZDateTime.now(tz.local).add(const Duration(seconds: 3)),
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
                        /// Schedule notification if switch in ON
                        await Utils.requestPermission(Permission.notification);
                        await scheduleNotification();
                      } else {
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
              SharedPrefsUtil.putInt('scheduledTimeMinute', newTimeOfDay.minute);
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
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
