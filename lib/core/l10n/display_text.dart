/// Text drawn in the display font (Yusei Magic, `OsdTextScaleRole.display`).
///
/// intl writes U+202F (NARROW NO-BREAK SPACE) in some formats: English
/// times (`DateFormat.jm`, "8:00 PM"), French numbers of 1 000 and more
/// ("1 234"), some dates. Yusei Magic has no glyph for it, so every
/// formatted string drawn in a display style goes through [safe] first. Add
/// the key to `_displayRoleKeys` in
/// `test/theme/display_font_coverage_test.dart` as well.
abstract final class DisplayText {
  /// U+202F, which Yusei Magic lacks.
  static const String narrowNoBreakSpace = '\u202F';

  /// U+00A0, which it draws, and which still never breaks a line.
  static const String noBreakSpace = '\u00A0';

  /// [text] with every narrow no-break space made a no-break space.
  static String safe(String text) =>
      text.replaceAll(narrowNoBreakSpace, noBreakSpace);
}
