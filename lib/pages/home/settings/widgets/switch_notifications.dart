import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../../utils/constants.dart';
import '../../../../utils/notification_service.dart';
import '../../../../utils/utils.dart';

class SwitchNotificationsComponent extends StatefulWidget {
  @override
  _SwitchNotificationsComponentState createState() =>
      _SwitchNotificationsComponentState();
}

class _SwitchNotificationsComponentState
    extends State<SwitchNotificationsComponent> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final int notificationId = 1;

  @override
  void initState() {
    super.initState();

    /// Initializing notification settings
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const IOSInitializationSettings iosInitializationSettings =
        IOSInitializationSettings();

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
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel id',
          'channel name',
          'channel description',
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
      // Allow notification to be shown daily
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'notifications'.tr,
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
                  },
                  activeTrackColor: AppColors.mainColor.withOpacity(0.4),
                  activeColor: AppColors.mainColor,
                ),
              ),
            ],
          ),
        ),
        const Divider(),
      ],
    );
  }
}
