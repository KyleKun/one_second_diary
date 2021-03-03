import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/routes/app_pages.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  CustomAppBar({Key key})
      : preferredSize = Size.fromHeight(60.0),
        super(key: key);

  @override
  final Size preferredSize;

  void popupAction(String option) {
    if (option == 'Donate') {
      Get.toNamed(Routes.DONATION);
    }
    if (option == 'About') {
      _showAboutPopup();
    }
  }

  void _showAboutPopup() {
    showAboutDialog(
      applicationIcon: FlutterLogo(),
      applicationName: 'One Second Diary',
      applicationVersion: 'Version: 1.0',
      applicationLegalese: 'Copyright © Caio Pedroso, 2021',
      context: Get.context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> options = ['Donate', 'About'];
    return AppBar(
      automaticallyImplyLeading: false,
      title: Text(
        'One Second Diary',
        style: TextStyle(
          fontFamily: 'Magic',
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
