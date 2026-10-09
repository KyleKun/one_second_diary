import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A single-choice row: a label that turns bold when [selected], and a radio
/// at the end. Both weights follow Bold Text through the typography.
///
/// Semantics: `inMutuallyExclusiveGroup` and `checked`. Put `OsdDivider`s
/// between rows.
class OsdRadioRow extends StatelessWidget {
  const OsdRadioRow({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
  });

  final String label;

  final bool selected;

  /// Called when the row is tapped.
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) => OsdListRow(
    title: label,
    titleStyle: selected
        ? context.typography.titleSmall
        : context.typography.rowTitle,
    trailing: OsdRowTrailing.radio(selected: selected),
    minHeight: OsdSizes.radioRowHeight,
    onTap: onSelected,
    haptic: OsdHaptic.selection,
    checked: selected,
    inMutuallyExclusiveGroup: true,
  );
}
