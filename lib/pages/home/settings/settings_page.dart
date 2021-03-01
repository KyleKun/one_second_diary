import 'package:flutter/material.dart';
import 'package:one_second_diary/pages/home/settings/widgets/language_chooser.dart';
import 'widgets/switch_theme.dart';

class SettingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          SwitchThemeComponent(),
          LanguageChooser(),
        ],
      ),
    );
  }
}
