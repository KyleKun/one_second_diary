import 'package:flutter/widgets.dart';

/// How far a kind of text may grow with the system text size. Apply it with
/// `OsdTextScaleClamp` or [OsdTextScale.scalerFor].
enum OsdTextScaleRole {
  /// The app root. Every layout is verified up to 2.0; rows grow through
  /// `minHeight`, never fixed heights.
  root(2.0),

  /// Display titles, big numbers and avatar initials (already 23–64 px).
  display(1.3),

  /// Nav labels in the fixed 72 px bar.
  navLabel(1.2),

  /// Calendar day numbers and weekday letters in 42 px cells.
  calendar(1.2),

  /// Camera chrome, viewer action-tile labels and badges over media (Active,
  /// Saved, ClipDateLabel): fixed geometry over media.
  mediaChrome(1.3),

  /// The floating snackbar, which must not cover the screen.
  snackbar(1.4),

  /// Stamps, subtitles on video and onboarding artwork: what you see is what
  /// the export burns in, or part of an illustration.
  unscaled(1.0);

  const OsdTextScaleRole(this.maxScaleFactor);

  /// The largest text scale this role accepts.
  final double maxScaleFactor;
}

/// Text-scaling helpers.
///
/// Always read the scale with `MediaQuery.textScalerOf` and clamp it; never
/// use `textScaleFactor`, because Android 14 scales nonlinearly.
abstract final class OsdTextScale {
  /// The font size [factorOf] measures the effective scale at (body text).
  static const double referenceFontSize = 14;

  /// The stats bento collapses to one column above this scale.
  static const double bentoSingleColumnAbove = 1.3;

  /// Names (profiles, movies) and the Diary's month title wrap to a second
  /// line from this scale, then ellipsize (WCAG 1.4.4).
  static const double twoLineNamesFrom = 1.3;

  /// Button rows stack vertically above this scale.
  static const double stackButtonRowsAbove = 1.5;

  /// Segmented tabs hide their icons above this scale.
  static const double hideSegmentIconsAbove = 1.5;

  /// Row values move under the row title from this scale.
  static const double valuesUnderTitleFrom = 1.6;

  /// MakeMovieChip goes icon-only from this scale.
  static const double iconOnlyChipFrom = 1.6;

  /// The effective text scale at body size, e.g. 1.3 when 14 px text renders
  /// at 18.2 px. Compare it with the thresholds above.
  static double factorOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(referenceFontSize) /
      referenceFontSize;

  /// How many lines a name gets: one as designed, two from
  /// [twoLineNamesFrom].
  static int nameLines(BuildContext context) =>
      factorOf(context) >= twoLineNamesFrom - .001 ? 2 : 1;

  /// The ambient text scaler clamped for [role], for a single `Text`
  /// (`Text(…, textScaler: OsdTextScale.scalerFor(context, role))`).
  static TextScaler scalerFor(BuildContext context, OsdTextScaleRole role) {
    if (role == OsdTextScaleRole.unscaled) return TextScaler.noScaling;
    return MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: role.maxScaleFactor);
  }
}
