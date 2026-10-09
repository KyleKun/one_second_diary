import 'dart:math' as math;

/// Where a clip saved from a trim selection ends: exactly where the
/// selection ends. The end is not padded, so a 1 s quick cut saves 1.000 s.
/// The `strictClipLength` preference key stays listed (`PrefKeys`), unread.
abstract final class ClipTrimPolicy {
  /// The end to save, in whole ms, for a selection ending at
  /// [selectedEndMilliseconds] (fractional, like the trimmer's value) in a
  /// source of [videoDurationMilliseconds]: the selection floored to the
  /// ms, never past the source's end.
  static int resolveEndMilliseconds({
    required double selectedEndMilliseconds,
    required int videoDurationMilliseconds,
  }) => math.min(
    math.max(0, selectedEndMilliseconds.floor()),
    videoDurationMilliseconds,
  );
}
