import 'package:flutter/animation.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Today's own timings where the design system has no token for them. Read
/// every duration through `OsdMotion.d`, so reduced motion caps it.
abstract final class TodayMotion {
  /// The header date crossfading at midnight.
  static const Duration dayChange = Duration(milliseconds: 250);
  static const Curve dayChangeCurve = Curves.easeOut;

  /// The frame morphing between the landscape and the portrait shape when
  /// the profile switches.
  static const Duration orientationMorph = OsdMotion.emphasizedLong;
  static const Curve orientationMorphCurve = OsdMotion.emphasizedCurve;

  /// The day's clips fading in over the dashed frame from [clipsInScale];
  /// the dashed frame fades out over `OsdMotion.fast`.
  static const Duration clipsIn = Duration(milliseconds: 260);
  static const Curve clipsInCurve = Curves.easeOutCubic;
  static const double clipsInScale = .98;

  /// A clip's Saved badge lands this long after its clip arrives, over
  /// [badgeLanding].
  static const Duration badgeDelay = Duration(milliseconds: 120);
  static const Duration badgeLanding = Duration(milliseconds: 280);

  /// How long the Saved badge stays once it is up, before it fades out
  /// over [badgeFade].
  static const Duration badgeShown = Duration(seconds: 3);
  static const Duration badgeFade = Duration(milliseconds: 600);

  /// One glow of the record button, from the disc to gone (the
  /// `avatar_glow` package's default).
  static const Duration recordGlow = Duration(milliseconds: 2000);

  /// The button rests this long between two glows.
  static const Duration recordGlowRest = Duration(milliseconds: 1000);

  /// Record's row and Edit / Add another swapping: a fade and a rise.
  static const Duration controlsSwap = Duration(milliseconds: 240);
  static const Curve controlsSwapCurve = Curves.easeOutCubic;
  static const double controlsSwapRise = 8;

  /// The saved snackbar waits this long after Today shows again, so it
  /// lands just after the badge.
  static const Duration snackbarDelay = Duration(milliseconds: 200);

  /// The pager moving to a clip that just arrived in the day.
  static const Duration newClipInView = Duration(milliseconds: 360);
  static const Curve newClipInViewCurve = Curves.easeInOutCubic;

  /// The pager settling again after a clip went away.
  static const Duration resnap = Duration(milliseconds: 250);

  /// The pager moving to the page of a tapped dot.
  static const Duration dotTap = OsdMotion.emphasizedLong;
  static const Curve dotTapCurve = Curves.easeOutCubic;

  /// The overlays coming back after a clip played.
  static const Duration overlaysBack = Duration(milliseconds: 200);

  /// How long the loading frame may show before its slow-load bar appears.
  static const Duration slowLoad = Duration(milliseconds: 300);
}
