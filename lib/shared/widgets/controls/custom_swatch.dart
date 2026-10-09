import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/controls/color_swatch_button.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_surface.dart';

/// The last swatch of the colour grid, which opens the custom colour picker.
///
/// Before a custom colour exists: C2 with a `colorize` glyph and no hairline.
/// Once one is chosen: that colour (with the hairline, the ring and the
/// check of a [ColorSwatchButton]) plus a small badge at the bottom-end so it
/// still reads as "custom". Tapping it opens the picker again.
class CustomSwatch extends StatelessWidget {
  const CustomSwatch({
    super.key,
    this.color,
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
    this.diameter = 34,
  });

  /// The `colorize` glyph of the empty swatch.
  static const Key glyphKey = Key('customSwatch.glyph');

  static const Key badgeKey = Key('customSwatch.badge');

  /// The custom colour, once chosen.
  final Color? color;

  /// Whether the custom colour is the stamp colour.
  final bool selected;

  final String semanticsLabel;

  /// Opens the picker.
  final VoidCallback? onTap;

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = this.color;
    return ColorSwatchButton(
      color: color ?? colors.c2,
      selected: selected,
      semanticsLabel: semanticsLabel,
      onTap: onTap,
      diameter: diameter,
      hairline: color != null,
      glyph: color == null
          ? OsdIcon(
              OsdIcons.colorize,
              key: glyphKey,
              size: 18,
              color: colors.tx,
            )
          : null,
      badge: color == null
          ? null
          : DecoratedBox(
              key: badgeKey,
              decoration: BoxDecoration(
                color: colors.c2,
                shape: BoxShape.circle,
                border: Border.all(
                  color: OsdSurface.of(context).color(colors),
                  width: 1.5,
                ),
              ),
              child: SizedBox.square(
                dimension: 14,
                child: Center(
                  child: OsdIcon(OsdIcons.colorize, size: 10, color: colors.tx),
                ),
              ),
            ),
    );
  }
}
