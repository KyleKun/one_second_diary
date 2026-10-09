import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/domain/language_catalog.dart';

void main() {
  test('finds each of the 12 languages v1.7 could store by its code, and '
      'nothing for a code the app has no translation for', () {
    // The `lang` values the picker of older installs wrote.
    const List<String> v17Codes = <String>[
      'de', 'en', 'pt', 'es', 'id', 'zh', 'fr', 'ru', 'cs', 'ca', 'be', 'hu', //
    ];
    for (final String code in v17Codes) {
      expect(LanguageCatalog.byCode(code)?.code, code, reason: code);
    }
    // What older installs stored from the device on a first launch.
    for (final String code in <String>['it', 'ja', 'fil', 'su', '', 'EN']) {
      expect(LanguageCatalog.byCode(code), isNull, reason: code);
    }
  });

  test('keeps the flags v1.7 showed, listed in the language sheet order '
      '(S7, O11/O18)', () {
    expect(
      <(String, String, String)>[
        for (final AppLanguage l in AppLanguage.values)
          (l.code, l.nativeName, l.flagCountryCode),
      ],
      <(String, String, String)>[
        ('ca', 'Català', 'AD'),
        ('cs', 'Čeština', 'CZ'),
        ('de', 'Deutsch', 'DE'),
        ('en', 'English', 'US'),
        ('es', 'Español', 'ES'),
        ('fr', 'Français', 'FR'),
        ('id', 'Bahasa Indonesia', 'ID'),
        ('hu', 'Magyar', 'HU'),
        ('pt', 'Português', 'BR'),
        ('be', 'Беларуская', 'BY'),
        ('ru', 'Русский', 'RU'),
        ('zh', '中文', 'CN'),
      ],
    );
  });

  test('every language has intl date symbols, so the calendar never throws '
      '(Z MB-11)', () async {
    await initializeDateFormatting();

    for (final AppLanguage language in AppLanguage.values) {
      expect(
        () => DateFormat.yMMM(language.code).format(DateTime(2026, 9)),
        returnsNormally,
        reason: language.code,
      );
    }
  });
}
