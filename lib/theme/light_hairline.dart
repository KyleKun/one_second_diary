import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_surface.dart';

/// Draws the light theme's 1 px LN hairline over a CARD surface that sits on
/// BG.
///
/// The hairline is painted in the foreground and takes no layout space, so
/// the content sits at the same place in both themes. Nothing is drawn in the
/// dark theme or on other surfaces (sheets, C2 tiles, buttons, media).
///
/// [radius] is the card's corner radius. [inset] moves the hairline inside a
/// transparent border (the inactive ProfileTile: inset 1.5, radius 18.5).
/// [visible] turns it off without changing the tree, for tiles whose
/// selected state draws a TX border instead.
class LightHairline extends StatelessWidget {
  const LightHairline({
    super.key,
    required this.radius,
    this.inset = 0,
    this.visible = true,
    required this.child,
  });

  final BorderRadius radius;
  final double inset;

  /// Whether the hairline may show (it still needs the light theme and BG).
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visible =
        this.visible &&
        Theme.of(context).brightness == Brightness.light &&
        OsdSurface.of(context).cardGetsHairline;
    // The CustomPaint stays in the tree in both themes, so switching theme
    // never rebuilds the card's subtree from scratch.
    return CustomPaint(
      foregroundPainter: visible
          ? _HairlinePainter(
              color: context.colors.ln,
              radius: radius,
              inset: inset,
            )
          : null,
      child: child,
    );
  }
}

class _HairlinePainter extends CustomPainter {
  const _HairlinePainter({
    required this.color,
    required this.radius,
    required this.inset,
  });

  final Color color;
  final BorderRadius radius;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(inset);
    Border.all(color: color).paint(canvas, rect, borderRadius: radius);
  }

  @override
  bool shouldRepaint(_HairlinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.inset != inset;
}
