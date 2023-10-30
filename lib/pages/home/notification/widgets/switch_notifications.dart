import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../routes/app_pages.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/notification_service.dart';
import '../../../../utils/theme.dart';

class SwitchNotificationsComponent extends StatefulWidget {
  @override
  _SwitchNotificationsComponentState createState() =>
      _SwitchNotificationsComponentState();
}

class _SwitchNotificationsComponentState
    extends State<SwitchNotificationsComponent> {
  late bool isNotificationSwitchToggled;
  TimeOfDay scheduledTimeOfDay = const TimeOfDay(hour: 20, minute: 00);
  late bool isPersistentSwitchToggled;
  NotificationService notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    isNotificationSwitchToggled = notificationService.isNotificationActivated();
    isPersistentSwitchToggled = notificationService.isPersistentNotificationActivated();

    // Sets the default values for scheduled time
    scheduledTimeOfDay = notificationService.getScheduledTime();
  }

  @override
  void dispose() {
    super.dispose();
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
                Switch(
                  value: isNotificationSwitchToggled,
                  onChanged: (value) async {
                    if (value) {
                      await notificationService.turnOnNotifications();
                      await notificationService.scheduleNotification(
                          scheduledTimeOfDay.hour,
                          scheduledTimeOfDay.minute);
                    } else {
                      await notificationService.turnOffNotifications();
                    }

                    /// Update switch value
                    setState(() {
                      isNotificationSwitchToggled = !isNotificationSwitchToggled;
                    });
                  },
                  activeTrackColor: AppColors.mainColor.withOpacity(0.4),
                  activeColor: AppColors.mainColor,
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        // if (NotificationService().isNotificationActivated()) ...{
        //   InkWell(
        //     onTap: showTestNotification,
        //     child: Container(
        //       padding: const EdgeInsets.symmetric(horizontal: 15.0),
        //       child: Row(
        //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //         children: [
        //           Text(
        //             'test'.tr,
        //             style: TextStyle(
        //               fontSize: MediaQuery.of(context).size.width * 0.045,
        //             ),
        //           ),
        //           IconButton(
        //             onPressed: showTestNotification,
        //             splashRadius: 24,
        //             icon: const Icon(
        //               Icons.play_arrow,
        //               color: Colors.green,
        //             ),
        //           ),
        //         ],
        //       ),
        //     ),
        //   ),
        //   const Divider(),
        // },
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

            // Enable notification if it's disabled
            if (!isNotificationSwitchToggled) {
              await notificationService.turnOnNotifications();
              setState(() {
                isNotificationSwitchToggled = true;
              });
            }

            notificationService.setScheduledTime(newTimeOfDay.hour,
                newTimeOfDay.minute);

            setState(() {
              scheduledTimeOfDay = newTimeOfDay;
            });

            await notificationService.scheduleNotification(
                scheduledTimeOfDay.hour,
                scheduledTimeOfDay.minute);
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'usePersistentNotifications'.tr,
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width * 0.045,
                ),
              ),
              Switch(
                value: isPersistentSwitchToggled,
                onChanged: (value) async {
                  if (value) {
                    notificationService.activatePersistentNotifications();
                  } else {
                    notificationService.unactivatePersistentNotifications();
                  }

                  /// Schedule notification if switch in ON
                  if(isNotificationSwitchToggled && !isNotificationSwitchToggled){
                    await notificationService.turnOnNotifications();
                    setState(() {
                      isNotificationSwitchToggled = true;
                    });
                  }

                  if(isNotificationSwitchToggled){
                    await notificationService.scheduleNotification(
                        scheduledTimeOfDay.hour,
                        scheduledTimeOfDay.minute);
                  }

                  /// Update switch value
                  setState(() {
                    isPersistentSwitchToggled = !isPersistentSwitchToggled;
                  });
                },
                activeTrackColor: AppColors.mainColor.withOpacity(0.4),
                activeColor: AppColors.mainColor,
              ),
            ],
          ),
        ),
        const Divider(),
      ],
    );
  }
}
