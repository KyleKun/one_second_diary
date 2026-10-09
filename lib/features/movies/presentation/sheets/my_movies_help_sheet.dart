import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_help_item.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// "About movies", from the help button of My movies: what a movie is, then
/// what the page does: play, select, the two views, the profile label and where
/// a new movie is made.
class MyMoviesHelpSheet extends StatelessWidget {
  const MyMoviesHelpSheet({super.key});

  static const Key bodyKey = Key('myMoviesHelpSheet.body');

  static Future<void> show(BuildContext context) => showOsdSheet<void>(
    context,
    title: Strings.myMoviesHelpTitle,
    subtitle: Strings.myMoviesHelpBody,
    looseSubtitle: true,
    child: const MyMoviesHelpSheet(key: bodyKey),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    spacing: OsdSpace.s16,
    children: <Widget>[
      OsdHelpItem(
        icon: OsdIcons.playArrow,
        title: Strings.myMoviesHelpPlayTitle,
        body: Strings.myMoviesHelpPlayBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.touchApp,
        title: Strings.myMoviesHelpSelectTitle,
        body: Strings.myMoviesHelpSelectBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.viewAgenda,
        title: Strings.myMoviesHelpViewTitle,
        body: Strings.myMoviesHelpViewBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.person,
        title: Strings.myMoviesHelpProfileTitle,
        body: Strings.myMoviesHelpProfileBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.movie,
        title: Strings.myMoviesHelpCreateTitle,
        body: Strings.myMoviesHelpCreateBody,
      ),
    ],
  );
}
