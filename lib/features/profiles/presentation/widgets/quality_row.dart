import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/features/profiles/presentation/profile_labels.dart';
import 'package:one_second_diary/shared/widgets/surfaces/field_label.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// The "Quality" row of the new profile and convert sheets: the chosen
/// preset (or format summary) with a chevron, opening the quality sheet.
class QualityRow extends StatelessWidget {
  const QualityRow({
    super.key,
    required this.format,
    required this.onTap,
    this.enabled = true,
  });

  static const Key rowKey = Key('qualityRow.row');

  /// The format chosen; null before any (a new profile without a canvas
  /// yet).
  final ClipFormat? format;

  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ClipFormat? format = this.format;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.s8,
      children: <Widget>[
        FieldLabel(label: Strings.quality),
        OsdCard(
          tone: OsdCardTone.c2,
          margin: EdgeInsets.zero,
          child: OsdListRow(
            key: rowKey,
            title: format == null
                ? Strings.quality
                : ProfileLabels.formatOrPreset(format),
            subtitle: format == null ? null : ProfileLabels.format(format),
            icon: OsdIcons.tune,
            trailing: const OsdRowTrailing.chevron(),
            enabled: enabled,
            onTap: enabled ? onTap : null,
          ),
        ),
      ],
    );
  }
}
