import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'widgets/switch_notifications.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'notifications'.tr,
          style: TextStyle(
            fontFamily: 'Magic',
            fontSize: MediaQuery.of(context).size.width * 0.05,
          ),
        ),
      ),
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              SwitchNotificationsComponent(),
            ],
          ),
        ),
      ),
    );
  }
}
