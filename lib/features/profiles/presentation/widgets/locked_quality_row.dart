import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/features/profiles/presentation/profile_labels.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The read-only quality of "Edit profile": the preset or format summary
/// over why it never changes ("A profile's quality never changes, so its
/// movies stay fast…"), with a lock. One text node for screen readers.
class LockedQualityRow extends StatelessWidget {
  const LockedQualityRow({super.key, required this.format});

  static const Key lockKey = Key('lockedQualityRow.lock');

  final ClipFormat format;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.c2,
          borderRadius: BorderRadius.circular(OsdRadius.r16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            spacing: 12,
            children: <Widget>[
              OsdIcon(OsdIcons.tune, color: colors.mu),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: <Widget>[
                    Text(
                      ProfileLabels.formatOrPreset(format),
                      style: typography.rowTitleStrong.copyWith(
                        color: colors.tx,
                      ),
                    ),
                    Text(
                      ProfileLabels.format(format),
                      style: typography.rowSubtitle.copyWith(color: colors.mu),
                    ),
                    Text(
                      Strings.qualityFixed,
                      style: typography.caption.copyWith(
                        color: colors.sub,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              OsdIcon(
                OsdIcons.lock,
                key: LockedQualityRow.lockKey,
                color: colors.fa,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
