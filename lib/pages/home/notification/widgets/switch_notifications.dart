import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../routes/app_pages.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/custom_dialog.dart';
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
  late TimeOfDay scheduledTimeOfDay;
  late bool isPersistentSwitchToggled;
  final NotificationService notificationService = Get.find();

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
                      // show custom permission dialog
                      if (await Permission.notification.isPermanentlyDenied) {
                        await showNotificationDialog();
                        return;
                      }

                      // show system permission dialog
                      await notificationService.turnOnNotifications();
                      if (notificationService.isNotificationActivated()) {
                        setState(() {
                          isNotificationSwitchToggled = true;
                        });
                        notificationService
                            .rescheduleNotifications(
                          scheduledTimeOfDay.hour,
                          scheduledTimeOfDay.minute,
                        );
                      }
                    } else {
                      await notificationService.turnOffNotifications();
                      setState(() {
                        isNotificationSwitchToggled = false;
                      });
                    }
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
              // show custom permission dialog
              if (await Permission.notification.isPermanentlyDenied) {
                await showNotificationDialog();
                return;
              }

              // show system permission dialog
              await notificationService.turnOnNotifications();
              if (notificationService.isNotificationActivated()) {
                setState(() {
                  isNotificationSwitchToggled = true;
                });
              }
            }

            notificationService.setScheduledTime(newTimeOfDay.hour, newTimeOfDay.minute);
            setState(() {
              scheduledTimeOfDay = newTimeOfDay;
            });

            notificationService.rescheduleNotifications(
              scheduledTimeOfDay.hour,
              scheduledTimeOfDay.minute,
            );
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
                    notificationService.deactivatePersistentNotifications();
                  }
                  setState(() {
                    isPersistentSwitchToggled = value;
                  });

                  if (isNotificationSwitchToggled) {
                    notificationService.rescheduleNotifications(
                      scheduledTimeOfDay.hour,
                      scheduledTimeOfDay.minute,
                    );
                  }
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

  Future<void> showNotificationDialog() async {
    await showDialog(
      barrierDismissible: false,
      context: Get.context!,
      builder: (context) =>
          CustomDialog(
            isDoubleAction: true,
            title: 'permissionDenied'.tr,
            content: 'allPermissionDenied'.tr,
            actionText: 'noThanks'.tr,
            actionColor: Colors.red,
            action: () => Get.back(),
            action2Text: 'settings'.tr,
            action2Color: Colors.green,
            action2: () async {
              Get.back();
              await openAppSettings();
              const lifecycleChannel = SystemChannels.lifecycle;
              lifecycleChannel.setMessageHandler((msg) async {
                if (msg?.endsWith('resumed') == true) {
                  lifecycleChannel.setMessageHandler(null);
                  if (await Permission.notification.isGranted) {
                    // schedule notifications
                    notificationService.switchNotification();
                    setState(() {
                      isNotificationSwitchToggled = true;
                    });
                    notificationService
                        .rescheduleNotifications(
                      scheduledTimeOfDay.hour,
                      scheduledTimeOfDay.minute,
                    );
                  }
                }
                return null;
              });
            },
            sendLogs: false,
          ),
    );
  }
}
