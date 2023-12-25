import 'package:about/about.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../utils/constants.dart';
import '../../../../utils/theme.dart';

class AboutButton extends StatelessWidget {
  const AboutButton({Key? key}) : super(key: key);

  void showAbout(BuildContext context) {
    showAboutPage(
      title: Text(
        'about'.tr,
        style: const TextStyle(color: Colors.white),
      ),
      context: context,
      applicationVersion: 'appVersion'.tr,
      applicationLegalese: 'Copyright © Caio Pedroso, 2024',
      children: <Widget>[
        MarkdownPageListTile(
          icon: const Icon(
            Icons.history,
            color: AppColors.green,
          ),
          title: Text(
            'Changelog',
            style: TextStyle(
              color: ThemeService().isDarkTheme() ? Colors.white : Colors.black,
            ),
          ),
          filename: 'CHANGELOG.md',
        ),
        MarkdownPageListTile(
          icon: const Icon(
            Icons.favorite,
            color: AppColors.mainColor,
          ),
          title: Text(
            'thanksTo'.tr,
            style: TextStyle(
              color: ThemeService().isDarkTheme() ? Colors.white : Colors.black,
            ),
          ),
          filename: 'CONTRIBUTORS.md',
        ),
        LicensesPageListTile(
          title: Text(
            'licenses'.tr,
            style: TextStyle(
              color: ThemeService().isDarkTheme() ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
      applicationIcon: const SizedBox(
        width: 100,
        height: 100,
        child: Image(
          image: AssetImage('assets/images/app_logo.png'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showAbout(context),
      child: Ink(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.065,
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'about'.tr,
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width * 0.045,
                ),
              ),
              const Icon(Icons.info),
            ],
          ),
        ),
      ),
    );
  }
}
