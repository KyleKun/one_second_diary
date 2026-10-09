import 'package:flutter/animation.dart';

/// The camera's own timings and curves, where `OsdMotion` has no token.
/// They go through `OsdMotion.d` / `curve` too, so reduced motion caps
/// them.
abstract final class CameraMotion {
  /// Today's record button flies into the shutter, and the page fades in
  /// (`OsdPages.mediaFlight`).
  static const Duration enter = Duration(milliseconds: 280);

  /// The shutter's disc ↔ stop square, over `OsdMotion.standard`.
  static const Curve morphCurve = Curves.easeInOutCubic;

  /// The glyphs turning upright with the phone.
  static const Duration glyphTurn = Duration(milliseconds: 250);

  /// The explanation bubble coming in, over `OsdMotion.selection`.
  static const Curve bubbleInCurve = Cubic(.2, .9, .3, 1);

  /// How long the lock's explanation stays, and the unlock's.
  static const Duration lockedBubbleHold = Duration(seconds: 4);
  static const Duration unlockedBubbleHold = Duration(milliseconds: 2500);

  /// A countdown numeral starts leaving this long after it came.
  static const Duration countdownExitAt = Duration(milliseconds: 820);

  /// The focus ring stays this long once landed, then fades out.
  static const Duration focusHold = Duration(milliseconds: 800);
  static const Duration focusFade = Duration(milliseconds: 300);

  /// The spinner shows only when the lens takes longer than this to open.
  static const Duration spinnerDelay = Duration(milliseconds: 600);
}
