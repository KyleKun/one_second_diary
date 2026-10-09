import 'package:flutter/widgets.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';

/// An [OsdIcon] whose FILL axis tweens to [fill].
class OsdAnimatedIcon extends StatelessWidget {
  const OsdAnimatedIcon(
    this.icon, {
    super.key,
    required this.fill,
    this.size = OsdSizes.iconDefault,
    this.color,
    this.duration = OsdMotion.fast,
  });

  /// A glyph from `OsdIcons`.
  final IconData icon;

  /// The target FILL value.
  final double fill;

  final double size;

  final Color? color;

  /// How long a fill change takes.
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(end: fill),
    duration: OsdMotion.d(context, duration),
    curve: OsdMotion.curve(context, OsdMotion.fastCurve),
    builder: (context, value, _) =>
        OsdIcon(icon, size: size, fill: value.clamp(0, 1), color: color),
  );
}
