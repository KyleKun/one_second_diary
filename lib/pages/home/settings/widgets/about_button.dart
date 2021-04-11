import 'package:about/about.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/controllers/lang_controller.dart';

class AboutButton extends StatelessWidget {
  final LanguageController _languageController = Get.find();

  void showAbout(BuildContext context) {
    showAboutPage(
      title: Text('about'.tr),
      context: context,
      applicationVersion: 'appVersion'.tr,
      applicationLegalese: 'Copyright © Caio Pedroso, 2021',
      children: <Widget>[
        MarkdownPageListTile(
          filename: _languageController.selectedLanguage.value == 'pt'
              ? 'TODO_pt.md'
              : 'TODO.md',
          title: Text('futureUpdates'.tr),
          icon: Icon(Icons.more_time_outlined),
        ),
        MarkdownPageListTile(
          icon: Icon(Icons.list),
          title: const Text('Changelog'),
          filename: 'CHANGELOG.md',
        ),
        MarkdownPageListTile(
          icon: Icon(Icons.favorite),
          title: Text('thanksTo'.tr),
          filename: 'CONTRIBUTORS.md',
        ),
        LicensesPageListTile(title: Text('licenses'.tr)),
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
    return Container(
      child: Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.065,
            padding: EdgeInsets.symmetric(horizontal: 15.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'about'.tr,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.045,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.info),
                  onPressed: () => showAbout(context),
                ),
              ],
            ),
          ),
          Divider(),
        ],
      ),
    );
  }
}
