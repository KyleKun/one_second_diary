import 'package:flutter/painting.dart';

/// Theme-invariant colours and shadows drawn on top of video and thumbnails.
/// They are the same in both themes and are never tokens.
///
/// Blur radii convert CSS blurs with `(cssBlur / 2 − 0.5) / 0.57735`
/// (`OsdShadows.fromCssBlur`).
abstract final class OsdMedia {
  /// Text, icons and page dots on video; the trim window border.
  static const Color onMedia = Color(0xFFFFFFFF);

  /// Black @ .55: SavedBadge fill, multi-clip count badge.
  static const Color scrim55 = Color(0x8C000000);

  /// Black @ .50: VideoOverlayIconButton (36).
  static const Color scrim50 = Color(0x80000000);

  /// Black @ .45: PlayOverlayButton fill.
  static const Color scrim45 = Color(0x73000000);

  /// White @ .60: PlayOverlayButton 1.5 px border.
  static const Color ring60 = Color(0x99FFFFFF);

  /// Black @ .35: SelectionBadge.empty fill (with a 2 px [onMedia] ring).
  static const Color emptyBadgeFill = Color(0x59000000);

  /// BG-dark @ .6: FilmstripTrimmer outside the window.
  static const Color filmstripMask = Color(0x99151414);

  /// Grey @ .3: ColorSwatchButton inner 1 px hairline.
  static const Color swatchHairline = Color(0x4D808080);

  /// PageDots.onMedia inactive dot.
  static const Color onMediaDotInactive = Color(0x73FFFFFF);

  /// PageDots.onMedia active dot.
  static const Color onMediaDotActive = Color(0xFFFFFFFF);

  /// White @ .10: SnackbarActionPill and the info status badge.
  static const Color snackbarActionFill = Color(0x1AFFFFFF);

  /// Behind letterboxed video.
  static const Color letterbox = Color(0xFF000000);

  /// ProcessingThumb done badge circle.
  static const Color doneBadge = Color(0xFF7AC74F);

  /// The `check` on [doneBadge].
  static const Color doneBadgeInk = Color(0xFF151414);

  /// The stamps' outline (DateStamp, the clip editor's stamps): CSS
  /// `text-shadow: 0 0 2px #000` twice.
  static const List<Shadow> stampShadow = <Shadow>[
    Shadow(color: Color(0xFF000000), blurRadius: 0.87),
    Shadow(color: Color(0xFF000000), blurRadius: 0.87),
  ];

  static const List<Shadow> _lightStampShadow = <Shadow>[
    Shadow(color: Color(0xFFFFFFFF), blurRadius: 0.87),
    Shadow(color: Color(0xFFFFFFFF), blurRadius: 0.87),
  ];

  /// The stamp outline for a stamp drawn in [stampColor]: white when the
  /// colour's relative luminance is below .2, so dark stamps stay readable.
  static List<Shadow> stampShadowFor(Color stampColor) =>
      stampColor.computeLuminance() < .2 ? _lightStampShadow : stampShadow;

  /// The glyph colour on a swatch of [fill] (the swatch check, the clip
  /// editor's `colorize` dot): black when the fill's relative luminance is
  /// above .5, white otherwise.
  static Color inkOn(Color fill) => fill.computeLuminance() > .5
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);

  /// Calendar day number on a thumbnail (CSS 3 px).
  static const Shadow dayNumberShadow = Shadow(
    color: Color(0xE6000000),
    blurRadius: 1.73,
  );

  /// Bare play icon (CSS 6 px).
  static const Shadow playIconShadow = Shadow(
    offset: Offset(0, 1),
    blurRadius: 4.33,
    color: Color(0x99000000),
  );

  /// Empty and coral SelectionBadge (CSS 6 px).
  static const BoxShadow badgeShadow = BoxShadow(
    offset: Offset(0, 2),
    blurRadius: 4.33,
    color: Color(0x66000000),
  );

  /// Trim window while dragging.
  static const BoxShadow trimGlow = BoxShadow(
    spreadRadius: 4,
    color: Color(0x2EFFFFFF),
  );

  /// OsdSnackbar (CSS `0 12px 32px rgba(0,0,0,.35)`). The only UI chrome with
  /// a drop shadow.
  static const BoxShadow snackbarShadow = BoxShadow(
    offset: Offset(0, 12),
    blurRadius: 26.85,
    color: Color(0x59000000),
  );

  /// The picker tile's and the selectable MovieGridItem's scrim.
  static const LinearGradient clipScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0x73000000),
      Color(0x00000000),
      Color(0x00000000),
      Color(0x8C000000),
    ],
    stops: <double>[0, .38, .62, 1],
  );

  /// Date-stamp colours in sheet order (15, plus a custom picker).
  static const List<Color> stampSwatches = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFF212121),
    Color(0xFFEF5558),
    Color(0xFFE53935),
    Color(0xFFFFA500),
    Color(0xFFE5B25D),
    Color(0xFFFFEB3B),
    Color(0xFF7AC74F),
    Color(0xFF26A69A),
    Color(0xFF29B6F6),
    Color(0xFF3F51B5),
    Color(0xFF7D7ABC),
    Color(0xFFEC407A),
    Color(0xFF8D6E63),
    Color(0xFF9E9E9E),
  ];
}
