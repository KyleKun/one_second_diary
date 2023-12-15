import 'package:flutter/material.dart';

import 'widgets/about_button.dart';
import 'widgets/backup_tutorial.dart';
import 'widgets/contact_button.dart';
import 'widgets/github_button.dart';
import 'widgets/language_chooser.dart';
import 'widgets/notifications_button.dart';
import 'widgets/preferences_button.dart';
import 'widgets/profiles_button.dart';
import 'widgets/switch_theme.dart';
import 'widgets/switch_verticalmode.dart';

class SettingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.90,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 40.0),
        child: Scrollbar(
          interactive: true,
          thumbVisibility: true,
          radius: Radius.circular(30.0),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.0),
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Column(
                children: [
                  SwitchThemeComponent(),
                  SwitchVerticalModeComponent(),
                  PreferencesButton(),
                  NotificationsButton(),
                  ProfilesButton(),
                  LanguageChooser(),
                  BackupTutorial(),
                  GithubButton(),
                  ContactButton(),
                  AboutButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
