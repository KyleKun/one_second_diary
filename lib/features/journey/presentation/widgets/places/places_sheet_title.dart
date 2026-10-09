import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/display_text.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The sheet's heading: a display title over a caption, with an optional
/// action at the end.
class PlacesSheetTitle extends StatelessWidget {
  const PlacesSheetTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    return Row(
      spacing: 12,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  DisplayText.safe(title),
                  style: typography.displayValue.copyWith(color: colors.tx),
                ),
              ),
              Text(
                subtitle,
                style: typography.caption13.copyWith(color: colors.mu),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
