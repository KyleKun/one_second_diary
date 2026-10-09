import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_second_diary/core/media/policy/stamp_filter.dart';
import 'package:one_second_diary/core/media/policy/stamp_font.dart';
import 'package:one_second_diary/core/media/policy/stamp_font_policy.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_fonts.dart';

/// Every text style of the design, by role.
///
/// The styles carry no colour: apply one from `OsdColors` at the use site
/// (`t.rowTitle.copyWith(color: c.tx)`). Read it with `context.typography` or
/// [OsdTypography.of].
///
/// - **UI and display styles** are Rubik with no family fallback; the
///   engine falls back to the system font per missing glyph, which only
///   Chinese hits. Display styles are Rubik 600 at −0.015 em.
/// - **Stamp styles** preview the stamp that ffmpeg burns into the video, so
///   they use the same file: the `StampFontPolicy` font for the stamp's
///   text (Rubik; Noto Sans SC for Chinese; Yusei Magic first with the
///   "legacy font" preference, [legacyStampFont]), falling back to Rubik.
///
/// Uppercase roles ([overline], [sectionCaps]) need the text uppercased at the
/// use site.
@immutable
class OsdTypography extends ThemeExtension<OsdTypography> {
  const OsdTypography({
    this.locale,
    this.boldText = false,
    this.legacyStampFont = false,
  });

  /// Typography for [locale], with heavier weights when the platform's Bold
  /// Text setting is on (`MediaQuery.boldTextOf`), and the stamp font the
  /// "legacy font" preference asks for.
  factory OsdTypography.forLocale(
    Locale locale, {
    bool boldText = false,
    bool legacyStampFont = false,
  }) => OsdTypography(
    locale: locale,
    boldText: boldText,
    legacyStampFont: legacyStampFont,
  );

  /// The app locale, set on every style so `zh` resolves Simplified glyphs.
  final Locale? locale;

  /// Raises every UI and display weight by 100, capped at 700.
  final bool boldText;

  /// The "legacy font" preference: stamps prefer Yusei Magic, as the export
  /// then burns them.
  final bool legacyStampFont;

  /// Languages without letter case: uppercase roles drop their spacing.
  static const Set<String> _caselessLanguages = <String>{'zh', 'ja'};

  /// Tabular figures for timers and readouts (the clip editor's trim readout,
  /// the processing percent, the reminder time's digit roll):
  /// `style.copyWith(fontFeatures: tabularFigures)`.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// The typography of the nearest [Theme].
  ///
  /// Throws a [StateError] when the theme was not built by `OsdTheme`.
  static OsdTypography of(BuildContext context) {
    final typography = Theme.of(context).extension<OsdTypography>();
    if (typography == null) {
      throw StateError(
        'No OsdTypography in the theme. Build the MaterialApp theme with OsdTheme.dark()/light(), '
        'or wrap the subtree in OsdForcedDark.',
      );
    }
    return typography;
  }

  FontWeight _weight(FontWeight weight) {
    if (!boldText) return weight;
    final raised = math.min(weight.value + 100, FontWeight.w700.value);
    return FontWeight.values.firstWhere(
      (candidate) => candidate.value == raised,
    );
  }

  TextStyle _ui(
    double size,
    FontWeight weight, {
    double? height,
    double letterSpacing = 0,
  }) => TextStyle(
    fontFamily: OsdFonts.rubik,
    fontSize: size,
    fontWeight: _weight(weight),
    height: height,
    letterSpacing: letterSpacing,
    leadingDistribution: TextLeadingDistribution.even,
    locale: locale,
  );

  TextStyle _caps(double size, FontWeight weight, {required double em}) => _ui(
    size,
    weight,
    letterSpacing: _caselessLanguages.contains(locale?.languageCode)
        ? 0
        : em * size,
  );

  /// The style of a stamp showing [texts] (the date, and the place when
  /// both show), in the font the export burns for them.
  TextStyle _stamp(Iterable<String> texts, double size, double? height) {
    final StampFont font = StampFontPolicy.forTexts(
      texts,
      legacy: legacyStampFont,
    );
    return TextStyle(
      fontFamily: font.flutterFamily,
      fontFamilyFallback: const <String>[OsdFonts.rubik],
      fontSize: size,
      fontWeight: font.flutterWeight,
      height: height,
      letterSpacing: 0,
      leadingDistribution: TextLeadingDistribution.even,
      locale: locale,
    );
  }

  /// A display style of [size] and line [height]. Prefer the named roles
  /// below.
  TextStyle display(double size, double? height) =>
      _ui(size, FontWeight.w600, height: height, letterSpacing: -0.015 * size);

  // Display styles.

  /// 112: countdown numerals.
  TextStyle get displayCountdown => display(112, 1.0);

  /// 64: "Days recorded" number, reminder time.
  TextStyle get displayHero => display(64, 1.0);

  /// 34: stat values.
  TextStyle get displayStat => display(34, 1.05);

  /// 32: onboarding titles.
  TextStyle get displayOnboarding => display(32, 1.15);

  /// 30, one line: Today's date, tab titles, processing count.
  TextStyle get title30 => display(30, 1.1);

  /// 30, may wrap: last onboarding title, range title, "Movie created!".
  TextStyle get title30Wrap => display(30, 1.15);

  /// 28: app name, headlines, "Making your movie…".
  TextStyle get displayHeadline => display(28, 1.2);

  /// 26: "Which days?".
  TextStyle get displayHeading => display(26, 1.2);

  /// 24: the year, the camera sheet's "2s".
  TextStyle get displayValue => display(24, 1.2);

  /// 23: Today phrase.
  TextStyle get displayPhrase => display(23, 1.3);

  /// 20: onboarding's "365 days → 6 min movie".
  TextStyle get displayPill => display(20, 1.2);

  /// 17, inherits the line height: stat units (" days", " / 28").
  TextStyle get displayUnit => display(17, null);

  /// Avatar initials: half the avatar [diameter].
  TextStyle displayInitial(double diameter) => display(diameter / 2, 1.0);

  // Stamp styles: the font ffmpeg burns for the text (`StampFontPolicy`),
  // never scaled with text size.

  /// The date and place stamps on video ([texts]: every stamp shown, so
  /// they share one font as in the export), scaled with the video rect's
  /// [videoWidth]. Given the [canvas] format the clip is made in (the
  /// editor's preview), it is the burned stamp at that scale:
  /// `StampFilter.fontSizeFor` the format and the chosen [size] (40 px at
  /// 1080p for a medium stamp, growing with the canvas) on a canvas
  /// `ClipFormat.width` wide (WYSIWYG); otherwise the design's 13 px on a
  /// 390 wide frame.
  TextStyle stampMedia({
    required Iterable<String> texts,
    required double videoWidth,
    ClipFormat? canvas,
    StampSize size = StampSize.medium,
  }) => _stamp(
    texts,
    canvas == null
        ? 13 * videoWidth / 390
        : StampFilter.fontSizeFor(canvas, size) * videoWidth / canvas.width,
    1.2,
  );

  /// Today's empty-frame stamp.
  TextStyle stampPlaceholder(String text) => _stamp(<String>[text], 13, 1.2);

  /// Stamp preview tile.
  TextStyle stampPreview(String text) => _stamp(<String>[text], 20, 1.2);

  /// Onboarding polaroid labels.
  TextStyle stampPolaroid(String text) => _stamp(<String>[text], 13, 1.2);

  // UI styles (Rubik).

  /// 9/700: calendar multi-clip count badge.
  TextStyle get microBadge => _ui(9, FontWeight.w700);

  /// 11/700: calendar day numbers.
  TextStyle get dayNumber => _ui(11, FontWeight.w700);

  /// 12/400: small labels and counts.
  TextStyle get caption => _ui(12, FontWeight.w400);

  /// 12/600: inactive nav label, calendar weekday letters.
  TextStyle get navLabel => _ui(12, FontWeight.w600);

  /// 12/700: active nav label.
  TextStyle get navLabelActive => _ui(12, FontWeight.w700);

  /// 12/700: ActiveBadge "Active".
  TextStyle get badge12 => _ui(12, FontWeight.w700);

  /// 12.5/400: contact option subtitles.
  TextStyle get captionContact => _ui(12.5, FontWeight.w400);

  /// 13/400: month progress, "since …", hints, snackbar sub-line.
  TextStyle get caption13 => _ui(13, FontWeight.w400);

  /// 13/400/1.4: row subtitles, error lines.
  TextStyle get rowSubtitle => _ui(13, FontWeight.w400, height: 1.4);

  /// 13/400/1.45: onboarding footnote, coach bubble.
  TextStyle get footnote => _ui(13, FontWeight.w400, height: 1.45);

  /// 13/600: stat labels, Add video/photo labels, SavedBadge, tooltips.
  TextStyle get label13 => _ui(13, FontWeight.w600);

  /// 13/600: sentence-case labels ("Format", "Preview").
  TextStyle get sectionLabelSoft => _ui(13, FontWeight.w600);

  /// 13/600, .08 em, UPPERCASE: Today weekday.
  TextStyle get overline => _caps(13, FontWeight.w600, em: .08);

  /// 13/700: section labels, selected QuickCutChip, "Change", ClipDateLabel.
  TextStyle get sectionLabel => _ui(13, FontWeight.w700);

  /// 13/700, .06 em, UPPERCASE: month section headers.
  TextStyle get sectionCaps => _caps(13, FontWeight.w700, em: .06);

  /// 14/400: sheet subtitles, second lines, option subtitles.
  TextStyle get body14 => _ui(14, FontWeight.w400);

  /// 14/400/1.45: tips, descriptions, callouts.
  TextStyle get body14Loose => _ui(14, FontWeight.w400, height: 1.45);

  /// 14/500: ProfileChip name.
  TextStyle get chipLabel => _ui(14, FontWeight.w500);

  /// 14/600: unselected segmented tab, timer chip, "Select all".
  TextStyle get label14 => _ui(14, FontWeight.w600);

  /// 14/700: selected tab, snackbar action, camera chips, MakeMovieChip.
  TextStyle get label14Strong => _ui(14, FontWeight.w700);

  /// 15/400: Today greeting, summaries, app version.
  TextStyle get body15 => _ui(15, FontWeight.w400);

  /// 15/400/1.45: dialog body, processing wait text, camera panel body.
  TextStyle get body15Loose => _ui(15, FontWeight.w400, height: 1.45);

  /// 15/500: rows without subtitle, unselected radio rows, nav rows.
  TextStyle get rowTitle => _ui(15, FontWeight.w500);

  /// 15/600: rows with subtitle, text buttons, Skip, DashedButton.
  TextStyle get rowTitleStrong => _ui(15, FontWeight.w600);

  /// 15/700: snackbar title, info-card value, counts, compact buttons.
  TextStyle get titleSmall => _ui(15, FontWeight.w700);

  /// 16/400: text field input and hint.
  TextStyle get field => _ui(16, FontWeight.w400);

  /// 16/400/1.5: the last onboarding step's body, text areas.
  TextStyle get body16Loose => _ui(16, FontWeight.w400, height: 1.5);

  /// 16/500: language row.
  TextStyle get langName => _ui(16, FontWeight.w500);

  /// 16/700: the selected language row.
  TextStyle get langNameSelected => _ui(16, FontWeight.w700);

  /// 16/600: NeutralButton, DestructiveButton, sheet row names.
  TextStyle get buttonNeutral => _ui(16, FontWeight.w600);

  /// 16/700: PrimaryButton, viewer titles, profile name.
  TextStyle get button => _ui(16, FontWeight.w700);

  /// 17/400/1.5: onboarding body, viewer caption.
  TextStyle get body17Loose => _ui(17, FontWeight.w400, height: 1.5);

  /// 17/700: hero CTA label.
  TextStyle get buttonLarge => _ui(17, FontWeight.w700);

  /// 17/700: month header, empty-state title.
  TextStyle get monthTitle => _ui(17, FontWeight.w700);

  /// 18/600: OsdAppBar title.
  TextStyle get appBarTitle => _ui(18, FontWeight.w600);

  /// 18/700: "1 selected", onboarding option title.
  TextStyle get title18Strong => _ui(18, FontWeight.w700);

  /// 20/700: sheet, dialog and camera panel titles.
  TextStyle get sheetTitle => _ui(20, FontWeight.w700);

  /// 20/600: the reminder time's 12-hour "PM".
  TextStyle get timeSuffix => _ui(20, FontWeight.w600);

  /// 22/500: ReminderTimeSheet Cupertino picker.
  TextStyle get pickerText => _ui(22, FontWeight.w500);

  /// The stock-widget slots, coloured TX (MU for `bodySmall` and
  /// `labelSmall`), so pickers, `LicensePage` and dialogs match the design.
  TextTheme materialTextTheme(OsdColors colors) => TextTheme(
    displayLarge: displayHero.copyWith(color: colors.tx),
    displayMedium: displayStat.copyWith(color: colors.tx),
    displaySmall: title30.copyWith(color: colors.tx),
    headlineLarge: displayOnboarding.copyWith(color: colors.tx),
    headlineMedium: displayHeadline.copyWith(color: colors.tx),
    headlineSmall: displayValue.copyWith(color: colors.tx),
    titleLarge: appBarTitle.copyWith(color: colors.tx),
    titleMedium: rowTitle.copyWith(color: colors.tx),
    titleSmall: titleSmall.copyWith(color: colors.tx),
    bodyLarge: field.copyWith(color: colors.tx),
    bodyMedium: body14.copyWith(color: colors.tx),
    bodySmall: caption.copyWith(color: colors.mu),
    labelLarge: buttonNeutral.copyWith(color: colors.tx),
    labelMedium: label13.copyWith(color: colors.tx),
    labelSmall: navLabel.copyWith(color: colors.mu),
  );

  @override
  OsdTypography copyWith({
    Locale? locale,
    bool? boldText,
    bool? legacyStampFont,
  }) => OsdTypography(
    locale: locale ?? this.locale,
    boldText: boldText ?? this.boldText,
    legacyStampFont: legacyStampFont ?? this.legacyStampFont,
  );

  /// Fonts can't be interpolated, so the typography snaps at the midpoint.
  @override
  OsdTypography lerp(covariant ThemeExtension<OsdTypography>? other, double t) {
    if (other is! OsdTypography) return this;
    return t < .5 ? this : other;
  }

  @override
  bool operator ==(Object other) =>
      other is OsdTypography &&
      other.locale == locale &&
      other.boldText == boldText &&
      other.legacyStampFont == legacyStampFont;

  @override
  int get hashCode => Object.hash(locale, boldText, legacyStampFont);
}

/// `context.typography`: the [OsdTypography] of the nearest theme.
extension OsdTypographyContext on BuildContext {
  OsdTypography get typography => OsdTypography.of(this);
}
