import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_help_item.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// "About tags", from the help buttons beside "Edit tags" and the movie
/// flow's tag rows: what tags are for, the Diary filter and search, movies
/// by tag, that tags are kept in the file, and Settings › Tags.
class TagsHelpSheet extends StatelessWidget {
  const TagsHelpSheet({super.key});

  static const Key bodyKey = Key('tagsHelpSheet.body');

  static Future<void> show(BuildContext context) => showOsdSheet<void>(
    context,
    title: Strings.tagsHelpTitle,
    subtitle: Strings.tagsHelpBody,
    looseSubtitle: true,
    child: const TagsHelpSheet(key: bodyKey),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    spacing: OsdSpace.s16,
    children: <Widget>[
      OsdHelpItem(
        icon: OsdIcons.filterList,
        title: Strings.tagsHelpFilterTitle,
        body: Strings.tagsHelpFilterBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.movie,
        title: Strings.tagsHelpMoviesTitle,
        body: Strings.tagsHelpMoviesBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.save,
        title: Strings.tagsHelpKeptTitle,
        body: Strings.tagsHelpKeptBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.settings,
        title: Strings.tagsHelpManageTitle,
        body: Strings.tagsHelpManageBody,
      ),
    ],
  );
}
