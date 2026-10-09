import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';

/// The body every icon-only button shares: a glyph centred in a circle or
/// rounded square of [visualSize], in a hit area of at least [hitSize]. Use
/// the named buttons (`OsdIconButton`, `CircleIconButton`, …); this is their
/// building block.
///
/// Every icon-only button has a [tooltip], which is also its semantics label.
/// Disabled: the glyph turns [disabledColor], or the whole button fades when
/// that is null.
class OsdIconButtonFrame extends StatelessWidget {
  const OsdIconButtonFrame({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.visualSize,
    required this.glyphSize,
    required this.glyphColor,
    this.onPressed,
    this.fill,
    this.radius,
    this.glyphFill = 0,
    this.disabledColor,
    this.hitSize = OsdSizes.minTap,
    this.pressScale = .94,
    this.overlay = OsdPressOverlay.sel,
    this.haptic,
    this.glyphOffset = Offset.zero,
  });

  /// The visual (fill and glyph).
  static const Key surfaceKey = Key('osdIconButton.surface');

  final IconData icon;

  /// The tooltip and semantics label.
  final String tooltip;

  /// The visual diameter or side.
  final double visualSize;

  final double glyphSize;

  final Color glyphColor;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  /// The fill; transparent when null.
  final Color? fill;

  /// A rounded square with this radius; a circle when null.
  final double? radius;

  final double glyphFill;

  /// The glyph colour when disabled; null fades the button instead.
  final Color? disabledColor;

  /// The smallest hit area.
  final double hitSize;

  final double pressScale;

  final OsdPressOverlay overlay;

  /// Played on tap.
  final OsdHaptic? haptic;

  /// Nudges the glyph, for optical centring.
  final Offset glyphOffset;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = this.radius;
    final shape = radius == null ? BoxShape.circle : BoxShape.rectangle;
    final borderRadius = BorderRadius.circular(radius ?? visualSize / 2);
    final color = enabled || disabledColor == null ? glyphColor : disabledColor;
    Widget glyph = AnimatedSwitcher(
      duration: OsdMotion.d(context, OsdMotion.fast),
      child: OsdIcon(
        icon,
        key: ValueKey<(IconData, double)>((icon, glyphFill)),
        size: glyphSize,
        fill: glyphFill,
        color: color,
      ),
    );
    if (glyphOffset != Offset.zero) {
      glyph = Transform.translate(offset: glyphOffset, child: glyph);
    }
    final Widget result = OsdPressable(
      opacity: OsdPressable.opacityFor(
        enabled: enabled || disabledColor != null,
      ),
      onTap: onPressed,
      tooltip: tooltip,
      pressScale: pressScale,
      overlay: overlay,
      shape: shape,
      borderRadius: borderRadius,
      haptic: haptic,
      minHitSize: hitSize,
      child: SizedBox.square(
        key: surfaceKey,
        dimension: visualSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            shape: shape,
            borderRadius: radius == null ? null : borderRadius,
          ),
          child: Center(child: glyph),
        ),
      ),
    );
    return result;
  }
}
