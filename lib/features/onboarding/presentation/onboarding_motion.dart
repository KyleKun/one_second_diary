import 'package:flutter/animation.dart';

/// The onboarding's own motion: one-off entrances the design system has no
/// token for. Everything else comes from `OsdMotion`, and under reduced
/// motion none of this runs: the pages show at rest.
abstract final class OnboardingMotion {
  /// Next turns the page.
  static const Duration pageTurn = Duration(milliseconds: 420);
  static const Curve pageTurnCurve = Curves.easeOutCubic;

  /// A slide's title and body fade in and rise [textRise] px, [textDelay]
  /// after its artwork starts.
  static const Duration textDelay = Duration(milliseconds: 120);
  static const Duration textIn = Duration(milliseconds: 360);
  static const double textRise = 12;
  static const Curve textCurve = Curves.easeOutCubic;

  /// How much the artwork lags behind its card while the page is dragged:
  /// it moves at 0.75 of the page, so the frame outruns its contents.
  static const double parallax = .25;

  /// How fast a slide's text fades while its page is dragged away.
  static const double textFade = 1.2;

  // First slide: the polaroids are pinned one by one.

  static const Duration polaroidIn = Duration(milliseconds: 520);
  static const Duration polaroidStagger = Duration(milliseconds: 90);
  static const double polaroidDrop = 18;
  static const double polaroidScale = 1.08;

  /// Degrees the polaroid turns back while it lands.
  static const double polaroidTurn = 4;

  // Second slide: the film runs, the play badge pops, the pill counts.

  static const Duration bandIn = Duration(milliseconds: 480);
  static const double bandSlide = 40;
  static const Duration badgeDelay = Duration(milliseconds: 120);
  static const Duration badgeIn = Duration(milliseconds: 420);
  static const Duration badgeFade = Duration(milliseconds: 200);
  static const double badgeScale = .6;
  static const Duration pillDelay = Duration(milliseconds: 240);
  static const Duration pillIn = Duration(milliseconds: 360);
  static const double pillRise = 12;

  /// The "0 days" → "365 days" count-up.
  static const Duration countDelay = Duration(milliseconds: 300);
  static const Duration countUp = Duration(milliseconds: 900);

  /// The movie length and its arrow, once the count is done.
  static const Duration lengthIn = Duration(milliseconds: 200);
  static const double lengthSlide = 6;

  /// The film marquee's speed, in logical px per second.
  static const double marqueeSpeed = 24;

  // Third slide: the logo, then the stickers slapped on.

  static const Duration logoIn = Duration(milliseconds: 300);
  static const double logoScale = .9;
  static const Duration chipDelay = Duration(milliseconds: 160);
  static const Duration chipStagger = Duration(milliseconds: 70);
  static const Duration chipIn = Duration(milliseconds: 380);
  static const double chipScale = .85;

  // The orientation page builds up top to bottom on first display.

  static const Duration tipDelay = Duration(milliseconds: 80);
  static const Duration tilesDelay = Duration(milliseconds: 160);
  static const Duration tileStagger = Duration(milliseconds: 60);
  static const Duration tileIn = Duration(milliseconds: 320);
  static const double tileRise = 16;

  /// The name field and "Start my diary".
  static const Duration closingDelay = Duration(milliseconds: 280);

  /// The part of an entrance of length [total] between [start] and
  /// [start] + [length], eased by [curve].
  static Interval span(
    Duration start,
    Duration length,
    Duration total, {
    Curve curve = Curves.linear,
  }) {
    final double all = total.inMicroseconds.toDouble();
    return Interval(
      (start.inMicroseconds / all).clamp(0, 1),
      ((start + length).inMicroseconds / all).clamp(0, 1),
      curve: curve,
    );
  }
}
