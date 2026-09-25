import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:one_second_diary/utils/date_format_utils.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  final DateTime february = DateTime(2024, 2, 6);

  test('file names stay yyyy-MM-dd whatever the locale', () {
    expect(DateFormatUtils.getDate(february), '2024-02-06');
  });

  group('numeric date', () {
    const Map<String, String> expected = {
      'en': '02/06/2024',
      'en_US': '02/06/2024',
      'en_GB': '06/02/2024',
      'pt': '06/02/2024',
      'pt_PT': '06/02/2024',
      'es': '06/02/2024',
      'ca': '06/02/2024',
      'fr': '06/02/2024',
      'id': '06/02/2024',
      'de': '06.02.2024',
      'ru': '06.02.2024',
      'be': '06.02.2024',
      'cs': '06. 02. 2024',
      'zh': '2024/02/06',
      'hu': '2024. 02. 06.',
    };
    expected.forEach((locale, value) {
      test(locale, () {
        expect(DateFormatUtils.formatNumericDate(february, locale), value);
      });
    });
  });

  group('written date', () {
    const Map<String, String> expected = {
      'en': 'February 6, 2024',
      'en_GB': '6 February 2024',
      'pt': '6 de fevereiro de 2024',
      'es': '6 de febrero de 2024',
      'ca': '6 de febrer del 2024',
      'fr': '6 février 2024',
      'id': '6 Februari 2024',
      'de': '6. Februar 2024',
      'ru': '6 февраля 2024 г.',
      'be': '6 лютага 2024 г.',
      'cs': '6. února 2024',
      'zh': '2024年2月6日',
      'hu': '2024. február 6.',
    };
    expected.forEach((locale, value) {
      test(locale, () {
        expect(DateFormatUtils.formatWrittenDate(february, locale), value);
      });
    });

    test('Catalan elides "de" before a vowel with a plain apostrophe', () {
      // YuseiMagic draws the typographic apostrophe as a full-width glyph.
      expect(
        DateFormatUtils.formatWrittenDate(DateTime(2024, 4, 6), 'ca'),
        "6 d'abril del 2024",
      );
    });
  });
}
