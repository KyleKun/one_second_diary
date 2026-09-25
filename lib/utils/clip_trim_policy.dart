/// Resolves how a hand-picked trim selection's end point becomes the clip's
/// actual saved end point.
///
/// The app has always padded the user's raw trim-end selection by
/// [paddingMilliseconds] before saving. `strictClipLength` lets a
/// user opt into saving exactly what they selected instead.
class ClipTrimPolicy {
  ClipTrimPolicy._();

  /// The legacy buffer added on top of the user's trim-end selection when
  /// not in strict mode.
  static const int paddingMilliseconds = 500;

  /// The end point (in milliseconds) to actually save, given the raw
  /// [selectedEndMilliseconds] from the trim UI.
  ///
  /// - Strict mode saves exactly what was selected, clamped to the source
  ///   video's own duration so it can never seek past the end of the file.
  /// - Legacy (default) mode adds [paddingMilliseconds] on top, also clamped
  ///   to the video's duration.
  static double resolveEndMilliseconds({
    required double selectedEndMilliseconds,
    required int videoDurationMilliseconds,
    required bool strictClipLength,
  }) {
    final double targetEnd = strictClipLength
        ? selectedEndMilliseconds
        : selectedEndMilliseconds + paddingMilliseconds;

    if (targetEnd > videoDurationMilliseconds) {
      return videoDurationMilliseconds.toDouble();
    }
    return targetEnd;
  }
}
