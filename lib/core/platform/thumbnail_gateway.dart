/// Extracts a still frame of a video into a JPEG file (`get_thumbnail_video`,
/// the app's only thumbnail plugin).
///
/// Concurrency, caching, priorities and cancellation live above this
/// boundary (`ThumbnailRepository`); the plugin runs every call on its own
/// unbounded thread pool.
abstract interface class ThumbnailGateway {
  /// Writes a JPEG of [videoPath] at [timeMs] to [outputPath], scaled to fit
  /// [maxWidth] × [maxHeight] with [quality] (0–100). Pass both bounds:
  /// Android only uses its fast scaled decoder when both are set.
  ///
  /// [outputPath] must be a file path ending in `.jpg`; anything else throws
  /// an [ArgumentError] (the plugin would treat it as a folder and write
  /// `<outputPath>/<video name>.jpg`, so two profiles' clips of one day would
  /// collide). The implementation creates the parent folder first, which the
  /// plugin does not do on either platform.
  ///
  /// Returns the written path, or null when the frame could not be extracted.
  Future<String?> writeThumbnail({
    required String videoPath,
    required String outputPath,
    required int maxWidth,
    required int maxHeight,
    required int quality,
    required int timeMs,
  });
}
