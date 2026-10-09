import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_help_item.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// "About private videos", from the help buttons beside "Make private" and
/// "Include private clips": what marking a video private does. It is left
/// out of movies, blurred where videos are browsed, still part of the
/// diary, and the mark is kept in the video's file.
class PrivateClipsHelpSheet extends StatelessWidget {
  const PrivateClipsHelpSheet({super.key});

  static const Key bodyKey = Key('privateClipsHelpSheet.body');

  static Future<void> show(BuildContext context) => showOsdSheet<void>(
    context,
    title: Strings.privateHelpTitle,
    subtitle: Strings.privateHelpBody,
    looseSubtitle: true,
    child: const PrivateClipsHelpSheet(key: bodyKey),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    spacing: OsdSpace.s16,
    children: <Widget>[
      OsdHelpItem(
        icon: OsdIcons.movie,
        title: Strings.privateHelpMoviesTitle,
        body: Strings.privateHelpMoviesBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.lock,
        title: Strings.privateHelpBlurTitle,
        body: Strings.privateHelpBlurBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.calendarMonth,
        title: Strings.privateHelpDiaryTitle,
        body: Strings.privateHelpDiaryBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.save,
        title: Strings.privateHelpKeptTitle,
        body: Strings.privateHelpKeptBody,
      ),
    ],
  );
}
