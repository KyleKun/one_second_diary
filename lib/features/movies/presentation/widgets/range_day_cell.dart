import 'package:flutter/material.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/shared/widgets/calendar/day_ring.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hit_slop.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_surface.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Where a day sits in the days picked.
enum RangeDayPart {
  /// Not picked.
  none,

  /// The first day (or the only one).
  start,

  /// The last day.
  end,

  /// Between the first and the last.
  between,
}

/// One day of the "Choose dates" grid, a pure widget: the grid passes the [day]
/// and its preformatted [number].
class RangeDayCell extends StatelessWidget {
  const RangeDayCell({
    super.key,
    required this.day,
    required this.number,
    required this.part,
    required this.hasClip,
    required this.enabled,
    required this.isToday,
    required this.semanticsLabel,
    this.onTap,
  });

  /// The cell of [day].
  static Key cellKey(LocalDay day) =>
      ValueKey<(String, LocalDay)>(('rangeDayCell', day));

  /// The dot on a day with a clip.
  static const Key dotKey = Key('rangeDayCell.dot');

  /// The cell height; with the row gap's slop, a 48 px tap target.
  static const double height = 42;

  static const double _dotSize = 4;

  final LocalDay day;

  /// The day of the month, formatted for the locale.
  final String number;

  final RangeDayPart part;

  /// Whether the day has a clip the movie would take.
  final bool hasClip;

  /// Whether the day can be picked.
  final bool enabled;

  final bool isToday;

  /// The full date and the day's state, for screen readers.
  final String semanticsLabel;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final bool filled = part == RangeDayPart.start || part == RangeDayPart.end;
    final Color ink = switch (part) {
      RangeDayPart.start || RangeDayPart.end => colors.onCo,
      RangeDayPart.between => colors.tx,
      RangeDayPart.none => enabled ? colors.tx : colors.fa,
    };
    final Widget cell = SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: <Widget>[
          DayRing(
            color: isToday ? colors.co : null,
            gap: OsdSurface.of(context).color(colors),
          ),
          if (part == RangeDayPart.between)
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.coFill,
                borderRadius: BorderRadius.circular(OsdRadius.r10),
              ),
            ),
          if (filled)
            Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.co,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          Center(
            child: Text(
              number,
              maxLines: 1,
              softWrap: false,
              textScaler: OsdTextScale.scalerFor(
                context,
                OsdTextScaleRole.calendar,
              ),
              style: context.typography.label14.copyWith(color: ink),
            ),
          ),
          if (hasClip)
            Positioned(
              bottom: OsdSpace.s4,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox.square(
                  key: dotKey,
                  dimension: _dotSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: filled ? colors.onCo : colors.co,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (!enabled) {
      return ExcludeSemantics(
        child: Opacity(
          opacity: OsdPressable.opacityFor(enabled: false),
          child: cell,
        ),
      );
    }
    return OsdHitSlop(
      slop: const EdgeInsets.symmetric(vertical: 3),
      child: OsdPressable(
        onTap: onTap,
        haptic: OsdHaptic.selection,
        pressScale: OsdPressScale.icon.scale,
        overlay: OsdPressOverlay.none,
        borderRadius: BorderRadius.circular(OsdRadius.r10),
        minHitSize: 0,
        selected: part != RangeDayPart.none,
        semanticsLabel: semanticsLabel,
        excludeChildSemantics: true,
        child: cell,
      ),
    );
  }
}
