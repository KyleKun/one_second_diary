import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_tints.dart';

/// The halo around Today's record button, painted outside the button's
/// box, so it takes no layout space.
///
/// - While [pulse] runs (the day waits for its clip): over each run, [glows] discs grow out of the button together along
///   `Curves.fastOutSlowIn`, the first to [glowFactor] of the button's radius past it, the second twice as far, while their
///   opacity falls evenly from [glowAlpha] to nothing. A run may end with a pause, the button alone ([glowShare]).
///   The first disc lies over the second, so the glow is denser near the button.
/// - At rest (a stopped [pulse]: reduced motion, a hidden tab): an inner
///   ring spread [innerSpread] over a fainter one spread [outerSpread];
///   [press] (0 → 1) grows them.
///
/// It repaints with [pulse] only: the loop never rebuilds or relays out.
class RecordHaloPainter extends CustomPainter {
  RecordHaloPainter({
    required this.color,
    required this.innerSpread,
    required this.outerSpread,
    required this.press,
    required this.pulse,
    this.glowShare = 1,
  }) : super(repaint: pulse);

  /// The glow's colour (the disc's).
  final Color color;

  /// How far the inner ring reaches past the disc at rest.
  final double innerSpread;

  /// How far the outer ring reaches past the disc at rest.
  final double outerSpread;

  /// How pressed the button is: 0 at rest, 1 held down.
  final double press;

  /// The glow loop: 0 → 1 once per glow and the pause after it, repeating.
  /// Stopped, the halo is at rest.
  final AnimationController pulse;

  /// The share of a [pulse] run the glow takes; nothing shows for the rest
  /// of it (the pause before the next glow).
  final double glowShare;

  /// How much a press widens the inner and the outer ring.
  static const double pressInnerGrowth = 2;
  static const double pressOuterGrowth = 4;

  /// How many discs a glow has.
  static const int glows = 2;

  /// How far the first disc grows past the button, as a share of the
  /// button's radius; disc n grows n times as far.
  static const double glowFactor = .25;

  /// The glow's opacity as it leaves the button.
  static const double glowAlpha = .22;

  static const Curve _glowCurve = Curves.fastOutSlowIn;

  /// How far the glow reaches past a button of [radius] at its widest.
  static double glowReach(double radius) => radius * glowFactor * glows;

  Color get innerColor => OsdTints.coTint14;

  /// The outer ring's colour at rest.
  Color get outerColor => OsdTints.coTint06;

  /// The inner ring's reach now.
  double get currentInnerSpread => innerSpread + pressInnerGrowth * press;

  /// The outer ring's reach now, at rest.
  double get currentOuterSpread => outerSpread + pressOuterGrowth * press;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;
    if (pulse.isAnimating) {
      final double progress = pulse.value / glowShare;
      // Between two glows: the button alone.
      if (progress >= 1) return;
      final Paint paint = Paint()
        ..color = color.withValues(alpha: glowAlpha * (1 - progress));
      final double grown = _glowCurve.transform(progress);
      // The widest first, so the smaller ones lie over it.
      for (int glow = glows; glow >= 1; glow--) {
        canvas.drawCircle(
          center,
          radius + radius * glowFactor * glow * grown,
          paint,
        );
      }
      return;
    }
    canvas
      ..drawCircle(
        center,
        radius + currentOuterSpread,
        Paint()..color = outerColor,
      )
      ..drawCircle(
        center,
        radius + currentInnerSpread,
        Paint()..color = innerColor,
      );
  }

  @override
  bool shouldRepaint(RecordHaloPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.innerSpread != innerSpread ||
      oldDelegate.outerSpread != outerSpread ||
      oldDelegate.press != press ||
      oldDelegate.glowShare != glowShare ||
      oldDelegate.pulse != pulse;
}
