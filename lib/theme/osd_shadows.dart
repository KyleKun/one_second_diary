import 'package:flutter/painting.dart';

/// Elevation and shadows.
///
/// There is no Material elevation anywhere: hierarchy comes from surface
/// colour and the light-theme hairline. The few drop shadows belong to media,
/// artwork and the snackbar (`OsdMedia`); outer selection rings are
/// unblurred spread shadows that take no layout space ([ring]).
abstract final class OsdShadows {
  /// Converts a CSS blur to a Flutter `blurRadius`.
  ///
  /// CSS uses sigma = blur / 2; Flutter uses sigma = 0.57735 × radius + 0.5.
  static double fromCssBlur(double cssBlur) => (cssBlur / 2 - 0.5) / 0.57735;

  /// Onboarding sticker chip (CSS 24 px).
  static const double stickerChipBlur = 19.9;

  /// Onboarding polaroid and play badge (CSS 30 px).
  static const double polaroidBlur = 25.1;

  /// Onboarding film band and logo tile (CSS 40 px).
  static const double filmBandBlur = 33.8;

  /// An outer selection ring: a [ring] band outside a [gap] band of the
  /// surface colour. The gap is painted last, so it sits on top.
  ///
  /// Calendar cells and swatches use the defaults (4 / 2); the selection ring
  /// uses a 3 spread.
  static List<BoxShadow> ring({
    required Color ring,
    required Color gap,
    double ringSpread = 4,
    double gapSpread = 2,
  }) => <BoxShadow>[
    BoxShadow(color: ring, spreadRadius: ringSpread),
    BoxShadow(color: gap, spreadRadius: gapSpread),
  ];
}
