/// Corner radius tokens.
///
/// Use `BorderRadius.circular(OsdRadius.r20)`, or
/// `const BorderRadius.all(Radius.circular(OsdRadius.r20))` where a constant
/// is needed.
abstract final class OsdRadius {
  /// Sheet handle, onboarding photo box, viewer progress.
  static const double r2 = 2;

  /// Mini progress bar.
  static const double r3 = 3;

  /// Page dots, flags, processing progress bar.
  static const double r4 = 4;

  /// Orientation thumbs, trim window, skeleton blocks, stop square.
  static const double r8 = 8;

  /// View-toggle segment.
  static const double r9 = 9;

  /// Calendar cell, segmented tab segment, filmstrip, "Change" pill, snackbar
  /// action pill, processing and filmstrip thumbs.
  static const double r10 = 10;

  /// IconTile, OptionTile, WarningPill, ViewToggle track, pressed text button.
  static const double r12 = 12;

  /// Segmented container, square icon buttons, clip and movie tiles, month
  /// tiles, hint chips, language rows, coach bubble, compact buttons (48).
  static const double r14 = 14;

  /// Buttons 50–54, text fields, callouts, contact tile, dashed button.
  static const double r16 = 16;

  /// Large buttons (56/58), snackbar, info card, option and tip cards.
  static const double r18 = 18;

  /// OsdCard, clip frame, mini player, memory card, profile tile.
  static const double r20 = 20;

  /// The stat tile.
  static const double r22 = 22;

  /// Large orientation tile, clip mosaic, movie preview card.
  static const double r24 = 24;

  /// The app logo.
  static const double r26 = 26;

  /// Sheets (top corners), dialogs, onboarding logo tile.
  static const double r28 = 28;

  /// TodayCard, onboarding illustration card.
  static const double r32 = 32;

  /// Stadium: chips, pills, badges, profile chip, outlined pill button.
  static const double full = 999;
}
