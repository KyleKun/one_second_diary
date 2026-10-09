import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A month of the month grid: [month] over [count]. **Disabled** (no clips,
/// the future, or below the movie minimum: [onTap] null): faded, and the
/// caller shows "—" as the count.
///
/// Semantics: `selected` in a mutually exclusive group, labelled "month,
/// count" unless [semanticsLabel] says otherwise ("October, no clips").
class MonthTile extends StatelessWidget {
  const MonthTile({
    super.key,
    required this.month,
    required this.count,
    required this.selected,
    required this.onTap,
    this.semanticsLabel,
  });

  static const Key surfaceKey = Key('monthTile.surface');

  static const Duration _fill = Duration(milliseconds: 160);

  /// The short month name.
  final String month;

  /// "31 clips", or "—".
  final String count;

  final bool selected;

  /// Chooses the month; null disables the tile.
  final VoidCallback? onTap;

  /// Overrides the "month, count" label.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final radius = BorderRadius.circular(OsdRadius.r14);
    final duration = OsdMotion.d(context, _fill);
    final curve = OsdMotion.curve(context, OsdMotion.fastCurve);
    final tile = OsdPressable(
      opacity: OsdPressable.opacityFor(enabled: onTap != null),
      onTap: onTap,
      haptic: OsdHaptic.selection,
      pressScale: OsdPressScale.button.scale,
      borderRadius: radius,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      semanticsLabel: semanticsLabel ?? '$month, $count',
      excludeChildSemantics: true,
      child: AnimatedContainer(
        key: surfaceKey,
        duration: duration,
        curve: curve,
        constraints: const BoxConstraints(
          minWidth: double.infinity,
          minHeight: 62,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.tx : colors.c2,
          borderRadius: radius,
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: selected ? 1 : 0),
          duration: duration,
          curve: curve,
          builder: (context, t, _) => Center(
            heightFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: <Widget>[
                  Text(
                    month,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.titleSmall.copyWith(
                      color: Color.lerp(colors.tx, colors.bg, t),
                    ),
                  ),
                  Text(
                    count,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.caption.copyWith(
                      color: Color.lerp(colors.mu, colors.bg, t),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return tile;
  }
}
