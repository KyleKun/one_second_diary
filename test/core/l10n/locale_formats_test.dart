import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';

void main() {
  setUpAll(initializeDateFormatting);

  test('formats in its language, or in the default language when intl has '
      'no data for it, with each language and formatter made once', () {
    final LocaleFormats english = LocaleFormats.forLocale('en');
    final LocaleFormats german = LocaleFormats.forLocale('de');
    final LocaleFormats unknown = LocaleFormats.forLocale('xx');

    expect(
      english.date('yMMMMd').format(DateTime(2024, 3, 12)),
      'March 12, 2024',
    );
    expect(
      german.date('yMMMMd').format(DateTime(2024, 3, 12)),
      '12. März 2024',
    );
    expect(german.numbers.format(1234), '1.234');
    expect(english.pattern('#,##0.#').format(1234.5), '1,234.5');
    expect(english.percent.format(.45), '45%');
    expect(german.symbols.STANDALONENARROWWEEKDAYS.first, 'S');
    expect(unknown.numbers.format(1234), '1,234');
    expect(unknown.date('yMMMd').format(DateTime(2024, 3, 12)), 'Mar 12, 2024');

    expect(LocaleFormats.forLocale('en'), same(english));
    expect(LocaleFormats.forLocale('fr'), isNot(same(english)));
    expect(english.date('yMMMd'), same(english.date('yMMMd')));
    expect(english.date('yMMMd'), isNot(same(english.date('MMMd'))));
    expect(english.pattern('#,##0.#'), same(english.pattern('#,##0.#')));
    expect(english.numbers, same(english.numbers));
  });
}
