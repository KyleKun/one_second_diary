import 'package:flutter/painting.dart';

/// Camera colours. The camera is always dark, so these never follow the
/// theme.
abstract final class OsdCamera {
  /// Camera background.
  static const Color black = Color(0xFF000000);

  /// Glass chips and buttons over the preview: black @ .50.
  static const Color glass = Color(0x80000000);

  /// Opaque camera panels and chips (ClipLengthChip).
  static const Color surface = Color(0xFF1C1B1A);

  /// Locked chips and inverted pills: TX-dark @ .92.
  static const Color ink = Color(0xEBF4F1EE);

  /// Content on [ink]: BG-dark.
  static const Color inkForeground = Color(0xFF151414);

  /// CoachBubble fill: BG-dark @ .92.
  static const Color bubble = Color(0xEB151414);

  /// CoachBubble text.
  static const Color bubbleText = Color(0xFFE6E1DC);

  /// Countdown numerals, timer text and icons on the preview.
  static const Color white = Color(0xFFFFFFFF);

  /// Barrier behind the camera sheet: black @ .65.
  static const Color scrim = Color(0xA6000000);

  /// Camera sheet slider inactive track.
  static const Color sliderTrackOff = Color(0xFF3F3B39);
}
