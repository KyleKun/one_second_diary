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

class SettingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.90,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 40.0),
        child: Scrollbar(
          interactive: true,
          thumbVisibility: true,
          radius: const Radius.circular(30.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SwitchThemeComponent(),
                  const PreferencesButton(),
                  const NotificationsButton(),
                  const ProfilesButton(),
                  const LanguageChooser(),
                  const BackupTutorial(),
                  const GithubButton(),
                  const ContactButton(),
                  const AboutButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
