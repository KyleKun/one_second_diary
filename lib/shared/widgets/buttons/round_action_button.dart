import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// "Add video" / "Add photo" on a Diary day: a C2 circle with a glyph,
/// then a label. The whole column is the tap target and one semantics
/// node.
class RoundActionButton extends StatelessWidget {
  const RoundActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.size = 52,
  });

  static const Key circleKey = Key('roundActionButton.circle');

  final IconData icon;

  final String label;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  /// The circle's diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Widget result = OsdPressable(
      opacity: OsdPressable.opacityFor(enabled: onPressed != null),
      onTap: onPressed,
      pressScale: OsdPressScale.icon.scale,
      overlay: OsdPressOverlay.none,
      semanticsLabel: label,
      excludeChildSemantics: true,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: <Widget>[
            Builder(
              builder: (context) => AnimatedContainer(
                key: circleKey,
                duration: OsdMotion.d(
                  context,
                  OsdPressable.isPressed(context)
                      ? OsdMotion.overlayIn
                      : OsdMotion.overlayOut,
                ),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: OsdPressable.isPressed(context)
                      ? Color.alphaBlend(
                          colors.tx.withValues(alpha: .06),
                          colors.c2,
                        )
                      : colors.c2,
                ),
                child: Center(child: OsdIcon(icon, size: 22, color: colors.d2)),
              ),
            ),
            Text(
              label,
              // Usually two lines; a long translation ("Fotó hozzáadása
              // videóként") takes a third rather than lose its end.
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.typography.label13.copyWith(color: colors.d2),
            ),
          ],
        ),
      ),
    );
    return result;
  }
}
