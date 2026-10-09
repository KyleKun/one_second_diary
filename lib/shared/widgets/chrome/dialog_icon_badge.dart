import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_tints.dart';

/// The badge above a dialog title: a centred circle in [tint] with a glyph in
/// [color]. It pops in; under reduced motion it only fades in.
class DialogIconBadge extends StatelessWidget {
  const DialogIconBadge({
    super.key,
    required this.icon,
    this.color,
    this.tint = OsdTints.redTint12,
  });

  static const Key circleKey = Key('dialogIconBadge.circle');

  final IconData icon;

  /// The glyph colour; RED by default.
  final Color? color;

  final Color tint;

  @override
  Widget build(BuildContext context) {
    final reduced = OsdMotion.reduced(context);
    return ExcludeSemantics(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: reduced
              ? OsdMotion.d(context, OsdMotion.fast)
              : const Duration(milliseconds: 300),
          curve: reduced
              ? Curves.linear
              : const Interval(.2, 1, curve: Curves.easeOutBack),
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0, 1),
            child: Transform.scale(
              scale: reduced ? 1 : .8 + .2 * t,
              child: child,
            ),
          ),
          child: SizedBox.square(
            key: circleKey,
            dimension: 64,
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
              child: Center(
                child: OsdIcon(
                  icon,
                  size: 32,
                  color: color ?? context.colors.red,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
