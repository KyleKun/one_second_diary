/// How long the in-app camera records.
abstract final class RecordingTiming {
  /// What the camera records past the clip length: the editor trims the
  /// file, so a clip is never shorter than asked when the camera starts
  /// late.
  static const Duration extra = Duration(seconds: 1);

  /// A recording stopped before this is dropped ("Too short to save").
  static const Duration shortest = Duration(milliseconds: 500);

  /// The countdown shows 3, 2, 1, a [countdownStep] each, and the camera
  /// starts when 1 has shown for its second.
  static const int countdownFrom = 3;
  static const Duration countdownStep = Duration(seconds: 1);

  /// How long the phone must stay in a new orientation before it counts.
  static const Duration orientationSettle = Duration(milliseconds: 500);

  /// How long the camera records for a clip of [clipSeconds].
  static Duration captureOf(int clipSeconds) =>
      Duration(seconds: clipSeconds) + extra;
}
