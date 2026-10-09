import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';

void main() {
  group('LocalDay', () {
    test('names a day yyyy-MM-dd (file stem) and yyyymmdd (key); both '
        'round-trip', () {
      expect(LocalDay(2024, 1, 5).fileStem, '2024-01-05');
      expect(LocalDay(2023, 12, 31).fileStem, '2023-12-31');
      expect(LocalDay(987, 3, 9).fileStem, '0987-03-09');
      expect(LocalDay(2024, 1, 5).key, 20240105);

      for (final LocalDay day in <LocalDay>[
        LocalDay(2024, 1, 5),
        LocalDay(1999, 12, 31),
        LocalDay(2024, 2, 29),
      ]) {
        expect(LocalDay.tryParseStem(day.fileStem), day);
        expect(LocalDay.fromKey(day.key), day);
      }
    });

    // DateTime would roll 2024-02-30 over to 1 March.
    test('rejects dates that do not exist, or fall outside 0000-9999, '
        'instead of rolling them over', () {
      for (final (int, int, int) date in <(int, int, int)>[
        (2024, 2, 30),
        (2023, 2, 29),
        (2024, 13, 1),
        (2024, 0, 1),
        (2024, 1, 0),
        // '10000-01-01' and '00-1-01-01' would not parse back.
        (10000, 1, 1),
        (-1, 1, 1),
      ]) {
        final (int year, int month, int day) = date;
        expect(
          () => LocalDay(year, month, day),
          throwsArgumentError,
          reason: '$date',
        );
      }
      expect(() => LocalDay.fromKey(20240230), throwsArgumentError);
      expect(() => LocalDay(9999, 12, 31).addDays(1), throwsArgumentError);
      expect(() => LocalDay.fromDateTime(DateTime(10000)), throwsArgumentError);
      for (final String stem in <String>[
        '2024-02-30',
        '2023-02-29',
        '2024-13-01',
        '2024-00-10',
        '2024-01-00',
      ]) {
        expect(LocalDay.tryParseStem(stem), isNull, reason: stem);
      }
      expect(LocalDay(2024, 2, 29).fileStem, '2024-02-29');
      expect(LocalDay(0, 1, 1).fileStem, '0000-01-01');
      expect(LocalDay(9999, 12, 31).fileStem, '9999-12-31');
    });

    test('tryParseStem rejects anything that is not exactly yyyy-MM-dd', () {
      for (final String stem in <String>[
        '',
        '2024-1-05',
        '2024-01-5',
        '24-01-05',
        '2024/01/05',
        ' 2024-01-05',
        '2024-01-05 ',
        '2024-01-05.mp4',
        '2024-01-05-2',
        '+2024-01-05',
        '２０２４-01-05',
      ]) {
        expect(LocalDay.tryParseStem(stem), isNull, reason: stem);
      }
    });

    test('fromDateTime takes the local calendar date of an instant, whatever '
        'the time of day', () {
      expect(
        LocalDay.fromDateTime(DateTime(2024, 3, 10)),
        LocalDay(2024, 3, 10),
      );
      expect(
        LocalDay.fromDateTime(DateTime(2024, 3, 10, 23, 59, 59, 999)),
        LocalDay(2024, 3, 10),
      );
      final DateTime instant = DateTime.utc(2024, 6, 30, 23, 30);
      final DateTime local = instant.toLocal();
      expect(
        LocalDay.fromDateTime(instant),
        LocalDay(local.year, local.month, local.day),
      );
    });

    test('day arithmetic crosses month, year and leap-day boundaries, and '
        'epochDay counts whole days since 1970-01-01', () {
      expect(LocalDay(2024, 1, 31).addDays(1), LocalDay(2024, 2, 1));
      expect(LocalDay(2024, 2, 28).addDays(1), LocalDay(2024, 2, 29));
      expect(LocalDay(2023, 12, 31).addDays(1), LocalDay(2024, 1, 1));
      expect(LocalDay(2024, 1, 1).addDays(-1), LocalDay(2023, 12, 31));
      expect(LocalDay(2024, 3, 1).addDays(-366), LocalDay(2023, 3, 1));

      expect(LocalDay(1970, 1, 1).epochDay, 0);
      expect(LocalDay(1970, 1, 2).epochDay, 1);
      expect(LocalDay(1969, 12, 31).epochDay, -1);
      expect(LocalDay(2024, 1, 1).epochDay, 19723);
      for (final LocalDay day in <LocalDay>[
        LocalDay(1969, 12, 31),
        LocalDay(2024, 2, 29),
        LocalDay(2038, 1, 19),
      ]) {
        expect(LocalDay.fromEpochDay(day.epochDay), day);
      }
    });

    test('steps exactly one calendar day across DST changes', () {
      // Spring-forward and fall-back days in Europe, the US, Chile and
      // Australia: a Duration(days: 1) step on local midnights is off by
      // one there in some time zones; a LocalDay step never is.
      final List<(LocalDay, LocalDay)> dstPairs = <(LocalDay, LocalDay)>[
        (LocalDay(2024, 3, 30), LocalDay(2024, 3, 31)),
        (LocalDay(2024, 10, 26), LocalDay(2024, 10, 27)),
        (LocalDay(2024, 3, 9), LocalDay(2024, 3, 10)),
        (LocalDay(2024, 11, 2), LocalDay(2024, 11, 3)),
        (LocalDay(2024, 9, 7), LocalDay(2024, 9, 8)),
        (LocalDay(2024, 4, 6), LocalDay(2024, 4, 7)),
      ];
      for (final (LocalDay before, LocalDay after) in dstPairs) {
        expect(before.addDays(1), after);
        expect(after.addDays(-1), before);
        expect(after.epochDay - before.epochDay, 1);
      }

      // Seven days back from a DST day lands on the same weekday.
      final LocalDay dstDay = LocalDay(2024, 3, 31);
      final LocalDay weekBefore = dstDay.addDays(-7);
      expect(weekBefore, LocalDay(2024, 3, 24));
      expect(
        weekBefore.toLocalDateTime().weekday,
        dstDay.toLocalDateTime().weekday,
      );
    });

    test('toLocalDateTime maps back to the same day for every day of 2024', () {
      LocalDay day = LocalDay(2024, 1, 1);
      for (int i = 0; i < 366; i++) {
        final DateTime local = day.toLocalDateTime();
        expect(local.isUtc, isFalse);
        expect(LocalDay.fromDateTime(local), day, reason: day.fileStem);
        day = day.addDays(1);
      }
    });

    test('compares chronologically, by value', () {
      final List<LocalDay> days = <LocalDay>[
        LocalDay(2024, 1, 2),
        LocalDay(2023, 12, 31),
        LocalDay(2024, 1, 1),
      ]..sort();
      expect(days, <LocalDay>[
        LocalDay(2023, 12, 31),
        LocalDay(2024, 1, 1),
        LocalDay(2024, 1, 2),
      ]);
      expect(LocalDay(2024, 1, 5), LocalDay(2024, 1, 5));
      expect(LocalDay(2024, 1, 5).hashCode, LocalDay(2024, 1, 5).hashCode);
      expect(LocalDay(2024, 1, 1).isBefore(LocalDay(2024, 1, 2)), isTrue);
      expect(LocalDay(2024, 1, 2).isBefore(LocalDay(2024, 1, 2)), isFalse);
      expect(LocalDay(2024, 1, 3).isAfter(LocalDay(2024, 1, 2)), isTrue);
      expect(LocalDay(2024, 1, 2).isAfter(LocalDay(2024, 1, 2)), isFalse);
    });
  });
}
