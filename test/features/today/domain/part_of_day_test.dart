// The character greets by the part of the day: morning 05:00–11:59,
// afternoon 12:00–17:59, evening 18:00–21:59, late night 22:00–04:59.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/today/domain/part_of_day.dart';

void main() {
  test('05:00 to 11:59 is the morning, 12:00 to 17:59 the afternoon, 18:00 '
      'to 21:59 the evening, 22:00 to 04:59 the late night, across '
      'midnight', () {
    final Map<DateTime, PartOfDay> table = <DateTime, PartOfDay>{
      DateTime(2026, 9, 28, 5): PartOfDay.morning,
      DateTime(2026, 9, 28, 9, 40): PartOfDay.morning,
      DateTime(2026, 9, 28, 11, 59): PartOfDay.morning,
      DateTime(2026, 9, 28, 12): PartOfDay.afternoon,
      DateTime(2026, 9, 28, 17, 59): PartOfDay.afternoon,
      DateTime(2026, 9, 28, 18): PartOfDay.evening,
      DateTime(2026, 9, 28, 21, 59): PartOfDay.evening,
      DateTime(2026, 9, 28, 22): PartOfDay.lateNight,
      DateTime(2026, 9, 28, 23, 59): PartOfDay.lateNight,
      DateTime(2026, 9, 29): PartOfDay.lateNight,
      DateTime(2026, 9, 29, 4, 59): PartOfDay.lateNight,
    };

    for (final MapEntry<DateTime, PartOfDay> row in table.entries) {
      expect(PartOfDay.at(row.key), row.value, reason: '${row.key}');
    }
  });

  test('the next change is the next 05:00, 12:00, 18:00 or 22:00; after '
      "22:00 the next day's 05:00; at it the part of the day is the next "
      'one', () {
    final Map<DateTime, DateTime> table = <DateTime, DateTime>{
      DateTime(2026, 9, 28, 0, 30): DateTime(2026, 9, 28, 5),
      DateTime(2026, 9, 28, 5): DateTime(2026, 9, 28, 12),
      DateTime(2026, 9, 28, 17, 59, 59): DateTime(2026, 9, 28, 18),
      DateTime(2026, 9, 28, 18): DateTime(2026, 9, 28, 22),
      DateTime(2026, 9, 28, 22): DateTime(2026, 9, 29, 5),
      DateTime(2026, 12, 31, 23): DateTime(2027, 1, 1, 5),
    };

    for (final MapEntry<DateTime, DateTime> row in table.entries) {
      final DateTime change = PartOfDay.nextChangeAfter(row.key);
      expect(change, row.value, reason: '${row.key}');
      expect(PartOfDay.at(change), isNot(PartOfDay.at(row.key)));
      expect(
        PartOfDay.at(change.subtract(const Duration(seconds: 1))),
        PartOfDay.at(row.key),
      );
    }
  });
}
