import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_media.dart';

/// The surface a widget sits on.
enum OsdSurfaceTone {
  /// The screen background (the default).
  bg,

  /// An OsdCard.
  card,

  /// An OsdSheet or OsdDialog.
  sheet,

  /// A C2 tile or input.
  c2,

  /// Video or a thumbnail.
  media;

  /// The surface colour, which is also the gap colour of an outer selection
  /// ring drawn on it (calendar rings on BG, swatch rings on SH).
  Color color(OsdColors colors) => switch (this) {
    OsdSurfaceTone.bg => colors.bg,
    OsdSurfaceTone.card => colors.card,
    OsdSurfaceTone.sheet => colors.sh,
    OsdSurfaceTone.c2 => colors.c2,
    OsdSurfaceTone.media => OsdMedia.letterbox,
  };

  /// A NeutralButton's fill: BTN on BG, C2 everywhere else (Edit on a card,
  /// Done/Reset on sheets).
  Color neutralFill(OsdColors colors) =>
      this == OsdSurfaceTone.bg ? colors.btn : colors.c2;

  /// Whether a CARD surface placed here gets the light-theme hairline: only
  /// on BG.
  bool get cardGetsHairline => this == OsdSurfaceTone.bg;
}

/// Tells descendants which surface they sit on, so components resolve the
/// surface rules themselves: the scaffold body is [OsdSurfaceTone.bg],
/// OsdCard provides [OsdSurfaceTone.card], OsdSheet and OsdDialog provide
/// [OsdSurfaceTone.sheet].
class OsdSurface extends InheritedWidget {
  const OsdSurface({super.key, required this.tone, required super.child});

  final OsdSurfaceTone tone;

  /// The nearest surface, or [OsdSurfaceTone.bg] when there is none.
  static OsdSurfaceTone of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OsdSurface>()?.tone ??
      OsdSurfaceTone.bg;

  @override
  bool updateShouldNotify(OsdSurface oldWidget) => oldWidget.tone != tone;
}
