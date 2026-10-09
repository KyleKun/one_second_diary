import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_nav_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// Create movie's other ways to pick the days: "Choose a month", "Choose
/// dates" and "Pick videos myself".
class MovieOptionsCard extends StatelessWidget {
  const MovieOptionsCard({
    super.key,
    required this.onChooseMonth,
    required this.onChooseDates,
    required this.onPickVideos,
  });

  static const Key cardKey = Key('movieOptionsCard.card');
  static const Key chooseMonthKey = Key('movieOptionsCard.chooseMonth');
  static const Key chooseDatesKey = Key('movieOptionsCard.chooseDates');
  static const Key pickVideosKey = Key('movieOptionsCard.pickVideos');

  final VoidCallback onChooseMonth;
  final VoidCallback onChooseDates;
  final VoidCallback onPickVideos;

  @override
  Widget build(BuildContext context) => OsdCard(
    key: cardKey,
    child: Column(
      children: <Widget>[
        OsdNavRow(
          key: chooseMonthKey,
          icon: OsdIcons.event,
          label: Strings.chooseMonth,
          onTap: onChooseMonth,
        ),
        const OsdDivider(),
        OsdNavRow(
          key: chooseDatesKey,
          icon: OsdIcons.calendarMonth,
          label: Strings.movieChooseDates,
          subtitle: Strings.movieChooseDatesSubtitle,
          onTap: onChooseDates,
        ),
        const OsdDivider(),
        OsdNavRow(
          key: pickVideosKey,
          icon: OsdIcons.checklist,
          label: Strings.createMoviePickVideos,
          onTap: onPickVideos,
        ),
      ],
    ),
  );
}
