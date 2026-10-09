import 'dart:math' as math;

/// The two thumbnail sizes the app keeps. Each tier bounds the frame's
/// longest side; the other side keeps the aspect ratio.
enum ThumbnailTier {
  /// Calendar cells, the pick grid, the movie progress strip and mosaic.
  cell(200),

  /// Today's card, the Diary mini player, the Memories feed, movie screens.
  poster(720);

  const ThumbnailTier(this.maxSide);

  /// The longest side, in pixels.
  final int maxSide;

  /// The bounds to ask the thumbnail gateway for, for a frame of [width] ×
  /// [height]: [maxSide] on the longer side, the other in proportion.
  ///
  /// Never a square: on Android 8.0 (API 26) the plugin scales the frame to
  /// EXACTLY the bounds given (`createScaledBitmap`); only from API 27 does it
  /// keep the aspect ratio. Square bounds distort every thumbnail there.
  ({int width, int height}) boundsFor({
    required int width,
    required int height,
  }) => width >= height
      ? (
          width: maxSide,
          height: math.max(1, (maxSide * height / width).round()),
        )
      : (
          width: math.max(1, (maxSide * width / height).round()),
          height: maxSide,
        );
}
