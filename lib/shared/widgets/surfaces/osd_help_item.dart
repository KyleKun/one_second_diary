import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// One line of a help sheet: a gesture or an option, with its icon, its
/// name and what it does. One semantics node.
class OsdHelpItem extends StatelessWidget {
  const OsdHelpItem({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: OsdSpace.s14,
        children: <Widget>[
          OsdIcon(icon, size: 22, color: colors.mu),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: OsdSpace.s2,
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
