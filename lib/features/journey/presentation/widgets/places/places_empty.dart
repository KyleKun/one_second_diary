import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_icon_disc.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_sheet_title.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// No clip has a place: how places get there, and why it matters for
/// imports.
class PlacesEmpty extends StatelessWidget {
  const PlacesEmpty({super.key, required this.onRecord});

  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: <Widget>[
        PlacesSheetTitle(
          title: Strings.placesNoneYet,
          subtitle: Strings.placesNoneBody,
        ),
        OsdCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: <Widget>[
              _HowRow(
                icon: OsdIcons.myLocation,
                accent: colors.green,
                title: Strings.placesHowLocationTitle,
                body: Strings.placesHowLocationBody,
              ),
              const OsdDivider(indent: 52),
              _HowRow(
                icon: OsdIcons.editLocationAlt,
                accent: colors.co,
                title: Strings.placesHowElsewhereTitle,
                body: Strings.placesHowElsewhereBody,
              ),
              const OsdDivider(indent: 52),
              _HowRow(
                icon: OsdIcons.lock,
                accent: colors.purple,
                title: Strings.placesHowStaysTitle,
                body: Strings.placesHowStaysBody,
              ),
            ],
          ),
        ),
        PrimaryButton(
          label: Strings.placesRecordToday,
          icon: OsdIcons.videocam,
          onPressed: onRecord,
        ),
        Text(
          Strings.placesNoneHint,
          textAlign: TextAlign.center,
          style: typography.caption13.copyWith(color: colors.mu),
        ),
      ],
    );
  }
}

class _HowRow extends StatelessWidget {
  const _HowRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: <Widget>[
          PlacesIconDisc(icon: icon, accent: accent),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: <Widget>[
                Text(
                  title,
                  style: typography.rowTitleStrong.copyWith(color: colors.tx),
                ),
                Text(
                  body,
                  style: typography.rowSubtitle.copyWith(color: colors.mu),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
