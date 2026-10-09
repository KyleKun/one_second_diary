// The Diary's dates and numbers in the app language, over the app's
// formatters: no DateFormat is constructed while a grid builds.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';

void main() {
  setUpAll(initializeDateFormatting);

  test('reads dates in the app language: the month title sentence-cased '
      '(es, pt and ru write months in lower case), the full date, the '
      'caption parts and the narrow weekdays from Sunday; a language intl '
      'has no data for falls back to the app default', () {
    final DiaryFormats english = DiaryFormats.forLocale('en');

    expect(english.monthTitle(const DiaryMonth(2026, 9)), 'September 2026');
    expect(
      DiaryFormats.forLocale('es').monthTitle(const DiaryMonth(2026, 9)),
      'Septiembre de 2026',
    );
    expect(english.fullDate(LocalDay(2026, 9, 16)), 'Wednesday, September 16');
    expect(english.weekday(LocalDay(2026, 9, 16)), 'Wednesday');
    expect(english.dayOfMonth(LocalDay(2026, 9, 16)), '16');
    expect(english.narrowWeekdays, <String>['S', 'M', 'T', 'W', 'T', 'F', 'S']);
    expect(DiaryFormats.forLocale('de').narrowWeekdays.take(2), <String>[
      'S',
      'M',
    ]);
    expect(
      DiaryFormats.forLocale('xx').monthTitle(const DiaryMonth(2026, 9)),
      isNotEmpty,
    );
  });

  test("its formats are the app's, made once per language", () {
    final DiaryFormats english = DiaryFormats.forLocale('en');

    expect(DiaryFormats.forLocale('en').numbers, same(english.numbers));
    expect(
      DiaryFormats.forLocale('en').narrowWeekdays,
      same(english.narrowWeekdays),
    );
    expect(DiaryFormats.forLocale('fr').numbers, isNot(same(english.numbers)));
  });
}
