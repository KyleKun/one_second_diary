import 'package:flutter/painting.dart';

/// Full-screen viewer colours: the clip viewer and the movie player, always
/// dark.
abstract final class OsdViewer {
  /// Viewer background.
  static const Color background = Color(0xFF000000);

  /// Action tiles under the video.
  static const Color tile = Color(0xFF1C1B1A);

  /// Pressed action tile.
  static const Color tilePressed = Color(0xFF262423);

  /// Subtitle and caption text.
  static const Color caption = Color(0xFFE6E1DC);

  /// Previous/next buttons: the pressed tile grey @ .9, which shows both
  /// over a bright video and over the black around it.
  static const Color navButton = Color(0xE6262423);

  /// Progress track: C2-dark.
  static const Color progressTrack = Color(0xFF2B2928);

  /// Progress fill.
  static const Color progressFill = Color(0xFFFFFFFF);
}
