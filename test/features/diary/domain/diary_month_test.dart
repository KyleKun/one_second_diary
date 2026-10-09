import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';

/// `MaterialLocalizations.firstDayOfWeekIndex`: 0 is Sunday (en_US), 1 is
/// Monday (de and most of Europe).
const int sunday = 0;
const int monday = 1;

void main() {
  test('a month holds its days (leap years too) and pages and orders '
      'across the year boundary', () {
    final DiaryMonth september = DiaryMonth.of(LocalDay(2026, 9, 16));

    expect(september, const DiaryMonth(2026, 9));
    expect(september.first, LocalDay(2026, 9, 1));
    expect(september.last, LocalDay(2026, 9, 30));
    expect(september.dayCount, 30);
    expect(september.contains(LocalDay(2026, 9, 30)), isTrue);
    expect(september.contains(LocalDay(2026, 10, 1)), isFalse);
    expect(const DiaryMonth(2024, 2).dayCount, 29);
    expect(const DiaryMonth(2026, 2).dayCount, 28);

    expect(const DiaryMonth(2026, 12).next, const DiaryMonth(2027, 1));
    expect(const DiaryMonth(2026, 1).previous, const DiaryMonth(2025, 12));
    expect(
      const DiaryMonth(2025, 12).isBefore(const DiaryMonth(2026, 1)),
      isTrue,
    );
    expect(
      const DiaryMonth(2026, 2).isAfter(const DiaryMonth(2026, 1)),
      isTrue,
    );
    expect(
      const DiaryMonth(2026, 1).isAfter(const DiaryMonth(2026, 1)),
      isFalse,
    );
  });

  test('the weeks of the grid follow the locale\'s first weekday '
      '(diary.md §8 test 1)', () {
    for (final (DiaryMonth month, int firstWeekday, int blanks, int weeks)
        in <(DiaryMonth, int, int, int)>[
          (const DiaryMonth(2026, 9), sunday, 2, 5),
          (const DiaryMonth(2026, 9), monday, 1, 5),
          // February 2026 starts on Sunday and fills 4 weeks.
          (const DiaryMonth(2026, 2), sunday, 0, 4),
          // May 2026 starts on a Friday: 5 blanks + 31 days = 36 slots.
          (const DiaryMonth(2026, 5), sunday, 5, 6),
          // June 2026 starts on a Monday.
          (const DiaryMonth(2026, 6), monday, 0, 5),
        ]) {
      expect(
        (
          month.leadingBlanks(firstWeekday: firstWeekday),
          month.weekCount(firstWeekday: firstWeekday),
        ),
        (blanks, weeks),
        reason: '$month from weekday $firstWeekday',
      );
    }
  });
}
