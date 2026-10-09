import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The weekday letters over the calendar grid: one per column, centred,
/// clamped like the days. MU, as FA text fails AA. At least [minHeight]
/// tall, the line box the grid's heights assume.
class WeekdayHeaderRow extends StatelessWidget {
  const WeekdayHeaderRow({super.key, required this.letters});

  static const double minHeight = 14;

  /// The 7 letters, in column order.
  final List<String> letters;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = context.typography.navLabel.copyWith(
      color: context.colors.mu,
    );
    final TextScaler scaler = OsdTextScale.scalerFor(
      context,
      OsdTextScaleRole.calendar,
    );
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Row(
          spacing: OsdSpace.gridGapCalendar,
          children: <Widget>[
            for (final String letter in letters)
              Expanded(
                child: Text(
                  letter,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  textScaler: scaler,
                  style: style,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
