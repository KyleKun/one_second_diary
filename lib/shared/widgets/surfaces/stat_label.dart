import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The label row of a stat tile: a filled icon in the stat's accent, then
/// the label (2 lines max).
class StatLabel extends StatelessWidget {
  const StatLabel({
    super.key,
    required this.icon,
    required this.accent,
    required this.label,
  });

  final IconData icon;

  /// The icon's colour.
  final Color accent;

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 6,
    children: <Widget>[
      OsdIcon(icon, size: 18, fill: 1, color: accent),
      Flexible(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.typography.label13.copyWith(color: context.colors.mu),
        ),
      ),
    ],
  );
}
