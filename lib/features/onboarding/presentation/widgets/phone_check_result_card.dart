import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/features/profiles/domain/quality_recommender.dart';
import 'package:one_second_diary/features/profiles/presentation/profile_labels.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The result card of the phone check: "Recommended for your phone", the
/// format selected (the pick, or what "Choose another" chose), why in one
/// line, and the picker's line for it.
class PhoneCheckResultCard extends StatelessWidget {
  const PhoneCheckResultCard({
    super.key,
    required this.recommendation,
    required this.selected,
    this.note,
  });

  static const Key cardKey = Key('phoneCheckResultCard');
  static const Key formatKey = Key('phoneCheckResultCard.format');

  final QualityRecommendation recommendation;

  /// The format the card shows selected.
  final ClipFormat selected;

  /// A line above the pick ("Checked Oct 7, 2026", the stale note).
  final String? note;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final LocaleFormats formats = LocaleFormats.of(context);
    final bool isPick = selected == recommendation.pick;
    final String? reason = isPick
        ? ProfileLabels.reason(recommendation, format: formats.numbers)
        : null;
    final String? line = ProfileLabels.availability(
      recommendation.of(selected),
      format: formats.numbers,
    );
    final ClipFormatPreset? preset = ClipFormatPreset.of(selected);
    return OsdCard(
      key: cardKey,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(OsdSpace.s16),
        child: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: OsdSpace.s8,
            children: <Widget>[
              Row(
                spacing: OsdSpace.chipIconGap,
                children: <Widget>[
                  OsdIcon(
                    OsdIcons.checkCircle,
                    size: 18,
                    fill: 1,
                    color: colors.greenInk,
                  ),
                  Expanded(
                    child: Text(
                      isPick ? Strings.phoneCheckResultTitle : Strings.quality,
                      style: typography.label13.copyWith(
                        color: colors.greenInk,
                      ),
                    ),
                  ),
                ],
              ),
              if (note != null)
                Text(
                  note!,
                  style: typography.caption.copyWith(color: colors.sub),
                ),
              Text(
                preset == null
                    ? ProfileLabels.format(selected)
                    : ProfileLabels.name(preset),
                key: formatKey,
                style: typography.rowTitleStrong.copyWith(color: colors.tx),
              ),
              if (preset != null)
                Text(
                  ProfileLabels.format(selected),
                  style: typography.rowSubtitle.copyWith(color: colors.mu),
                ),
              if (reason != null)
                Text(
                  reason,
                  style: typography.caption.copyWith(
                    color: colors.sub,
                    height: 1.4,
                  ),
                ),
              if (line != null)
                Text(
                  line,
                  style: typography.caption.copyWith(
                    color: colors.sub,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
