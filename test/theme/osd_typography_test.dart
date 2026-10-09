import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/stamp_font_policy.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/theme/osd_fonts.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Every display style, so a check covers the ones added later too.
final Map<String, TextStyle Function(OsdTypography t)> _displayStyles =
    <String, TextStyle Function(OsdTypography t)>{
      'displayCountdown': (t) => t.displayCountdown,
      'displayHero': (t) => t.displayHero,
      'displayStat': (t) => t.displayStat,
      'displayOnboarding': (t) => t.displayOnboarding,
      'title30': (t) => t.title30,
      'title30Wrap': (t) => t.title30Wrap,
      'displayHeadline': (t) => t.displayHeadline,
      'displayHeading': (t) => t.displayHeading,
      'displayValue': (t) => t.displayValue,
      'displayPhrase': (t) => t.displayPhrase,
      'displayPill': (t) => t.displayPill,
      'displayUnit': (t) => t.displayUnit,
      'displayInitial': (t) => t.displayInitial(44),
    };

void main() {
  // The preview draws the stamp in the file ffmpeg burns for its text.
  test('stamp styles use the font the export burns for the text', () {
    for (final (String text, bool legacy) in <(String, bool)>[
      ('October 1, 2026', false),
      ('1 октября 2026 г.', false),
      ('2026年10月1日', false),
      ('October 1, 2026', true),
      ('1 октября 2026 г.', true),
    ]) {
      final typography = OsdTypography.forLocale(
        const Locale('en'),
        boldText: true,
        legacyStampFont: legacy,
      );
      final burned = StampFontPolicy.forTexts(<String>[text], legacy: legacy);
      final stamps = <String, TextStyle>{
        'stampMedia': typography.stampMedia(
          texts: <String>[text],
          videoWidth: 390,
        ),
        'stampPlaceholder': typography.stampPlaceholder(text),
        'stampPreview': typography.stampPreview(text),
        'stampPolaroid': typography.stampPolaroid(text),
      };

      for (final MapEntry(key: name, value: style) in stamps.entries) {
        expect(style.fontFamily, burned.flutterFamily, reason: '$text $name');
        // The file's own weight, whatever Bold Text says.
        expect(style.fontWeight, burned.flutterWeight, reason: '$text $name');
      }
    }
    expect(
      OsdTypography.forLocale(
        const Locale('zh'),
      ).stampPreview('2026年10月1日').fontFamily,
      OsdFonts.notoSansSc,
    );
    expect(
      OsdTypography.forLocale(
        const Locale('en'),
        legacyStampFont: true,
      ).stampPreview('October 1, 2026').fontFamily,
      OsdFonts.magic,
    );
  });

  test('display styles are Rubik 600 in every language', () {
    for (final AppLanguage language in AppLanguage.values) {
      final typography = OsdTypography.forLocale(Locale(language.code));
      for (final MapEntry(key: name, value: read) in _displayStyles.entries) {
        final TextStyle style = read(typography);
        expect(style.fontFamily, OsdFonts.rubik, reason: '$language $name');
        expect(style.fontWeight, FontWeight.w600, reason: '$language $name');
      }
    }
  });

  test('Bold Text makes text heavier, capped at 700', () {
    final regular = OsdTypography.forLocale(const Locale('en'));
    final bold = OsdTypography.forLocale(const Locale('en'), boldText: true);

    expect(
      bold.rowTitle.fontWeight!.value,
      greaterThan(regular.rowTitle.fontWeight!.value),
    );
    expect(bold.button.fontWeight, FontWeight.w700, reason: 'capped at 700');
    expect(bold.title30.fontWeight, FontWeight.w700);
  });
}
