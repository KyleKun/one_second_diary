import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A sheet's title block: a title of up to 2 lines (a semantics header), an
/// optional accent [icon] before it, an optional [trailing] action (a help
/// button) at its end and an optional [subtitle] below.
class OsdSheetTitle extends StatelessWidget {
  const OsdSheetTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.looseSubtitle = false,
  });

  static const Key titleKey = Key('osdSheetTitle.title');

  final String title;

  final String? subtitle;

  final IconData? icon;

  /// TX by default.
  final Color? iconColor;

  /// An action at the end of the title's line.
  final Widget? trailing;

  /// Whether the subtitle uses the loose line height.
  final bool looseSubtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final icon = this.icon;
    final subtitle = this.subtitle;
    Widget heading = Semantics(
      header: true,
      child: Text(
        title,
        key: titleKey,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: typography.sheetTitle.copyWith(color: colors.tx),
      ),
    );
    if (icon != null) {
      heading = Row(
        spacing: 10,
        children: <Widget>[
          OsdIcon(icon, fill: 1, color: iconColor ?? colors.tx),
          Expanded(child: heading),
        ],
      );
    }
    final trailing = this.trailing;
    if (trailing != null) {
      heading = Row(
        spacing: 10,
        children: <Widget>[
          Expanded(child: heading),
          trailing,
        ],
      );
    }
    if (subtitle == null) return heading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: <Widget>[
        heading,
        Text(
          subtitle,
          style: (looseSubtitle ? typography.body14Loose : typography.body14)
              .copyWith(color: colors.mu),
        ),
      ],
    );
  }
}
