import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// WCAG 2.x contrast thresholds.
abstract final class Wcag {
  /// Body text, including every UI text at 15–17 px.
  static const double text = 4.5;

  /// Large text (≥ 24 px regular, ≥ 18.66 px bold) and non-text UI.
  static const double largeTextOrUi = 3.0;
}

/// Paints [layers] bottom to top: the first must be opaque, the others may be
/// translucent (a tint over a surface, a scrim over media).
Color composite(List<Color> layers) {
  assert(layers.first.a == 1, 'The bottom layer must be opaque');
  return layers
      .skip(1)
      .fold(layers.first, (below, above) => Color.alphaBlend(above, below));
}

/// The WCAG contrast ratio of [foreground] over [background]. A translucent
/// foreground is composited over the background first.
double contrastRatio(Color foreground, Color background) {
  assert(background.a == 1, 'Composite the background first');
  final front = Color.alphaBlend(foreground, background).computeLuminance();
  final back = background.computeLuminance();
  return (math.max(front, back) + 0.05) / (math.min(front, back) + 0.05);
}
