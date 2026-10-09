import 'dart:math' as math;
import 'dart:ui' show Size, lerpDouble;

/// The size of Today's clip frame: the card follows the profile's shape.
///
/// - Landscape: the card's inner width at 16:9, whatever the height; a
///   tablet caps the width.
/// - Portrait: as tall as the slot allows within its limits, at 9:16.
///
/// [minSlotHeight] is the least room the frame needs: below it the page
/// scrolls instead of shrinking the frame further. [frame] and
/// [minSlotHeight] take a `portraitness` from 0 (landscape) to 1
/// (portrait), so the orientation morph passes through the sizes in
/// between.
abstract final class TodayCardMetrics {
  /// A landscape clip's height over its width.
  static const double landscapeRatio = 9 / 16;

  /// A portrait clip's width over its height.
  static const double portraitRatio = 9 / 16;

  /// The tallest portrait frame on a phone.
  static const double portraitMaxHeight = 350;

  /// The tallest portrait frame on a tablet.
  static const double tabletPortraitMaxHeight = 480;

  /// The shortest portrait frame before the page scrolls.
  static const double portraitMinHeight = 200;

  /// The widest landscape frame on a tablet (360 tall).
  static const double tabletLandscapeMaxWidth = 640;

  /// The frame in a slot [innerWidth] wide and [slotHeight] tall.
  static Size frame({
    required double innerWidth,
    required double slotHeight,
    required double portraitness,
    required bool isTablet,
  }) => Size.lerp(
    _landscape(innerWidth, isTablet: isTablet),
    _portrait(slotHeight, isTablet: isTablet),
    portraitness,
  )!;

  /// The least height the slot needs for the frame (its intrinsic height).
  static double minSlotHeight({
    required double innerWidth,
    required double portraitness,
    required bool isTablet,
  }) => lerpDouble(
    _landscape(innerWidth, isTablet: isTablet).height,
    portraitMinHeight,
    portraitness,
  )!;

  static Size _landscape(double innerWidth, {required bool isTablet}) {
    final double width = isTablet
        ? math.min(innerWidth, tabletLandscapeMaxWidth)
        : innerWidth;
    return Size(width, width * landscapeRatio);
  }

  static Size _portrait(double slotHeight, {required bool isTablet}) {
    final double height = slotHeight.clamp(
      portraitMinHeight,
      isTablet ? tabletPortraitMaxHeight : portraitMaxHeight,
    );
    return Size(height * portraitRatio, height);
  }
}
