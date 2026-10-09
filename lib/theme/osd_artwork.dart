import 'package:flutter/painting.dart';

/// Onboarding illustration colours. The artwork is identical in both themes;
/// only the chrome around it switches. Its shadows are black at .18–.35.
abstract final class OsdArtwork {
  /// Polaroid paper.
  static const Color paper = Color(0xFFFAF7F2);

  /// Ink on the paper and sticker chips.
  static const Color ink = Color(0xFF2A2723);

  /// Green glyphs on the sticker chips.
  static const Color greenInk = Color(0xFF5FAE34);

  /// The film band.
  static const Color film = Color(0xFF141312);
}
