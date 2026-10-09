import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/light_hairline.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_surface.dart';

/// The surface of an [OsdCard].
enum OsdCardTone {
  /// CARD with the light hairline on BG: list cards.
  card,

  /// C2 inside sheets. No hairline.
  c2,

  /// CARD with the hairline, a larger radius and its own padding and margin.
  hero,
}

/// A grouped card.
///
/// It clips its content (`Clip.antiAlias`), so a row's pressed fill follows
/// the corners, and has no shadow. In the light theme a CARD sitting on BG
/// gets the LN hairline, painted in the foreground so the content never
/// moves. Descendants see `OsdSurface` [OsdSurfaceTone.card] (or
/// [OsdSurfaceTone.c2]), so neutral buttons inside turn C2.
///
/// The card itself is not interactive; with [onTap] the whole card presses.
class OsdCard extends StatelessWidget {
  const OsdCard({
    super.key,
    required this.child,
    this.tone = OsdCardTone.card,
    this.radius,
    this.padding,
    this.margin,
    this.onTap,
    this.semanticsLabel,
  });

  static const Key surfaceKey = Key('osdCard.surface');

  final Widget child;

  final OsdCardTone tone;

  /// The corner radius; the tone's by default.
  final double? radius;

  /// Inner padding; none, or the hero tone's, by default.
  final EdgeInsetsGeometry? padding;

  /// Outer margin; the page gutter on the sides (plus space above and below
  /// for [OsdCardTone.hero]) by default.
  final EdgeInsetsGeometry? margin;

  /// Makes the whole card tappable.
  final VoidCallback? onTap;

  /// The semantics label of a tappable card.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hero = tone == OsdCardTone.hero;
    final borderRadius = BorderRadius.circular(
      radius ?? (hero ? OsdRadius.r32 : OsdRadius.r20),
    );
    Widget card = ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        key: surfaceKey,
        decoration: BoxDecoration(
          color: tone == OsdCardTone.c2 ? colors.c2 : colors.card,
          borderRadius: borderRadius,
        ),
        child: Padding(
          padding:
              padding ??
              (hero
                  ? const EdgeInsets.fromLTRB(16, 16, 16, 24)
                  : EdgeInsets.zero),
          child: OsdSurface(
            tone: tone == OsdCardTone.c2
                ? OsdSurfaceTone.c2
                : OsdSurfaceTone.card,
            child: child,
          ),
        ),
      ),
    );
    if (tone != OsdCardTone.c2) {
      card = LightHairline(radius: borderRadius, child: card);
    }
    if (onTap != null) {
      card = OsdPressable(
        onTap: onTap,
        pressScale: OsdPressScale.infoCard.scale,
        borderRadius: borderRadius,
        semanticsLabel: semanticsLabel,
        child: card,
      );
    }
    return Padding(
      padding:
          margin ??
          (hero
              ? const EdgeInsets.symmetric(
                  horizontal: OsdSpace.pageGutter,
                  vertical: 14,
                )
              : const EdgeInsets.symmetric(horizontal: OsdSpace.pageGutter)),
      child: card,
    );
  }
}
