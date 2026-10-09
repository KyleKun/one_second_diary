import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';

/// A Material Symbols Rounded glyph at fixed axes: weight 400, grade 0,
/// optical size following the size (clamped to 20–48), and FILL 0 or 1.
///
/// Icons never scale with text. Directional glyphs (`OsdIcons.arrowBack`,
/// chevrons, `openInNew`) set `IconData.matchTextDirection`, so they mirror in
/// right-to-left layouts by themselves; media, orientation and artwork glyphs
/// never mirror.
class OsdIcon extends StatelessWidget {
  const OsdIcon(
    this.icon, {
    super.key,
    this.size = OsdSizes.iconDefault,
    this.fill = 0,
    this.color,
    this.shadows,
    this.semanticLabel,
  });

  /// A glyph from `OsdIcons`.
  final IconData icon;

  final double size;

  /// The FILL axis, 0 (outlined) to 1 (filled).
  final double fill;

  /// The glyph colour; the ambient `IconTheme` colour by default.
  final Color? color;

  /// Shadows, for glyphs drawn on media.
  final List<Shadow>? shadows;

  /// The semantics label. Most icons sit next to a label and have none.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Icon(
    icon,
    size: size,
    fill: fill,
    weight: 400,
    grade: 0,
    opticalSize: size.clamp(20, 48),
    color: color,
    shadows: shadows,
    semanticLabel: semanticLabel,
    applyTextScaling: false,
  );
}
