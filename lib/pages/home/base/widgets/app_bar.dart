import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/routes/app_pages.dart';
import 'package:share/share.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  CustomAppBar({Key key})
      : preferredSize = Size.fromHeight(60.0),
        super(key: key);

  @override
  final Size preferredSize;

  void popupAction(String option) {
    if (option == 'donate'.tr) {
      Get.toNamed(Routes.DONATION);
    }
    if (option == 'share'.tr) {
      Share.share('shareMsg'.tr);
    }
  }

  // void _showAboutPopup() {
  //   showAboutDialog(
  //     applicationIcon: FlutterLogo(),
  //     applicationName: 'One Second Diary',
  //     applicationVersion: 'appVersion'.tr,
  //     applicationLegalese: 'Copyright © Caio Pedroso, 2021',
  //     context: Get.context,
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final List<String> options = ['donate'.tr, 'share'.tr];
    return AppBar(
      automaticallyImplyLeading: false,
      title: Text(
        'One Second Diary',
        style: TextStyle(
          fontFamily: 'Magic',
          fontSize: MediaQuery.of(context).size.width * 0.05,
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: popupAction,
          itemBuilder: (BuildContext context) {
            return options.map((String option) {
              return PopupMenuItem<String>(
                value: option,
                child: Text(option),
              );
            }).toList();
          },
        ),
      ],
    );
  }
}
