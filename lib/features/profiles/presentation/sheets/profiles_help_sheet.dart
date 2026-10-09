import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_help_item.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// "About profiles", from the help button of the profiles page: what a
/// profile is, then the page's two gestures (tap to activate, long-press to
/// edit) with what each does.
class ProfilesHelpSheet extends StatelessWidget {
  const ProfilesHelpSheet({super.key});

  static const Key bodyKey = Key('profilesHelpSheet.body');

  static Future<void> show(BuildContext context) => showOsdSheet<void>(
    context,
    title: Strings.profilesHelpTitle,
    subtitle: Strings.profilesHelpBody,
    looseSubtitle: true,
    child: const ProfilesHelpSheet(key: bodyKey),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    spacing: OsdSpace.s16,
    children: <Widget>[
      OsdHelpItem(
        icon: OsdIcons.touchApp,
        title: Strings.tapToSwitch,
        body: Strings.profilesHelpActivateBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.edit,
        title: Strings.profilesHintLongPress,
        body: Strings.profilesHelpEditBody,
      ),
    ],
  );
}
