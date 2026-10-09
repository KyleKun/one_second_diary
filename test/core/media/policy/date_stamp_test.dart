import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:one_second_diary/core/media/policy/date_stamp.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/time/local_day.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  // Numeric and written stamps for 6 April 2024 and 31 December 2024, in
  // every app language and the regions the display locale can add. The
  // locale order, zero-padded; the CLDR long date; plain spaces where intl
  // uses no-break spaces (cs, hu, ru: the trimmed Noto Sans lacks U+202F)
  // and a plain apostrophe for U+2019 (ca: YuseiMagic draws it full width).
  test('equals v1.7 in every app language', () {
    const List<(String, String, String, String, String)>
    stamps = <(String, String, String, String, String)>[
      (
        'be',
        '06.04.2024',
        '6 красавіка 2024 г.',
        '31.12.2024',
        '31 снежня 2024 г.',
      ),
      (
        'ca',
        '06/04/2024',
        "6 d'abril del 2024",
        '31/12/2024',
        '31 de desembre del 2024',
      ),
      (
        'cs',
        '06. 04. 2024',
        '6. dubna 2024',
        '31. 12. 2024',
        '31. prosince 2024',
      ),
      ('de', '06.04.2024', '6. April 2024', '31.12.2024', '31. Dezember 2024'),
      ('en', '04/06/2024', 'April 6, 2024', '12/31/2024', 'December 31, 2024'),
      (
        'es',
        '06/04/2024',
        '6 de abril de 2024',
        '31/12/2024',
        '31 de diciembre de 2024',
      ),
      ('fr', '06/04/2024', '6 avril 2024', '31/12/2024', '31 décembre 2024'),
      (
        'hu',
        '2024. 04. 06.',
        '2024. április 6.',
        '2024. 12. 31.',
        '2024. december 31.',
      ),
      ('id', '06/04/2024', '6 April 2024', '31/12/2024', '31 Desember 2024'),
      (
        'pt',
        '06/04/2024',
        '6 de abril de 2024',
        '31/12/2024',
        '31 de dezembro de 2024',
      ),
      (
        'ru',
        '06.04.2024',
        '6 апреля 2024 г.',
        '31.12.2024',
        '31 декабря 2024 г.',
      ),
      ('zh', '2024/04/06', '2024年4月6日', '2024/12/31', '2024年12月31日'),
      (
        'en_US',
        '04/06/2024',
        'April 6, 2024',
        '12/31/2024',
        'December 31, 2024',
      ),
      ('en_GB', '06/04/2024', '6 April 2024', '31/12/2024', '31 December 2024'),
      ('en_AU', '06/04/2024', '6 April 2024', '31/12/2024', '31 December 2024'),
      (
        'pt_BR',
        '06/04/2024',
        '6 de abril de 2024',
        '31/12/2024',
        '31 de dezembro de 2024',
      ),
      (
        'pt_PT',
        '06/04/2024',
        '6 de abril de 2024',
        '31/12/2024',
        '31 de dezembro de 2024',
      ),
      (
        'es_MX',
        '06/04/2024',
        '6 de abril de 2024',
        '31/12/2024',
        '31 de diciembre de 2024',
      ),
      ('fr_CA', '2024-04-06', '6 avril 2024', '2024-12-31', '31 décembre 2024'),
      (
        'de_AT',
        '06.04.2024',
        '6. April 2024',
        '31.12.2024',
        '31. Dezember 2024',
      ),
      ('zh_TW', '2024/04/06', '2024年4月6日', '2024/12/31', '2024年12月31日'),
    ];
    final LocalDay april = LocalDay(2024, 4, 6);
    final LocalDay newYearsEve = LocalDay(2024, 12, 31);
    for (final (
          String locale,
          String aprilNumeric,
          String aprilWritten,
          String decemberNumeric,
          String decemberWritten,
        )
        in stamps) {
      String stamp(LocalDay day, StampFormat format) =>
          DateStamp.text(day, format: format, locale: locale);
      expect(
        <String>[
          stamp(april, StampFormat.numeric),
          stamp(april, StampFormat.written),
          stamp(newYearsEve, StampFormat.numeric),
          stamp(newYearsEve, StampFormat.written),
        ],
        <String>[aprilNumeric, aprilWritten, decemberNumeric, decemberWritten],
        reason: locale,
      );
    }
  });

  // The device region is added only when the device speaks the app language
  // and intl has data for it; an unknown or missing app language is English.
  test('DateStamp.displayLocale: the app language plus a same-language '
      'device region', () {
    const List<(String?, String?, String?, String)> cases =
        <(String?, String?, String?, String)>[
          // (app language, device language, device region, display locale)
          ('en', 'en', 'US', 'en_US'),
          ('en', 'en', 'GB', 'en_GB'),
          ('pt', 'pt', 'BR', 'pt_BR'),
          ('pt', 'pt', 'PT', 'pt_PT'),
          ('de', 'en', 'US', 'de'),
          ('ru', 'uk', 'UA', 'ru'),
          ('en', 'en', 'XX', 'en'),
          ('en', 'en', null, 'en'),
          ('xx', 'xx', 'YY', 'en'),
          (null, null, null, 'en'),
          (null, 'en', 'GB', 'en_GB'),
        ];
    for (final (String? app, String? language, String? region, String locale)
        in cases) {
      expect(
        DateStamp.displayLocale(
          appLanguage: app,
          deviceLanguage: language,
          deviceRegion: region,
        ),
        locale,
        reason: '$app, $language, $region',
      );
    }
  });
}
