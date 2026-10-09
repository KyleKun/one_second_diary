// The Journey statistics. Epoch days are `LocalDay.epochDay`; clip names
// and LocalDay itself are pinned by clip_name_codec_test and
// test/core/time/local_day_test.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/journey_math.dart';
import 'package:one_second_diary/features/clips/domain/month_progress.dart';

int d(int y, int m, int day) => LocalDay(y, m, day).epochDay;

List<int> days(Iterable<int> xs) => xs.toSet().toList()..sort();

void main() {
  test('the current streak counts days, ends today or yesterday, and is '
      'DST-safe', () {
    final int today = d(2026, 9, 28);
    // (why, history, streak, at risk)
    final List<(String, List<int>, int, bool)> rows =
        <(String, List<int>, int, bool)>[
          ('empty history', <int>[], 0, false),
          (
            'ends today',
            <int>[for (int i = 0; i < 12; i++) today - i],
            12,
            false,
          ),
          (
            'today not yet recorded: a run ending yesterday stays alive',
            <int>[for (int i = 1; i <= 12; i++) today - i],
            12,
            true,
          ),
          (
            'missed yesterday and today',
            <int>[for (int i = 2; i <= 12; i++) today - i],
            0,
            false,
          ),
          (
            'a gap breaks the run',
            <int>[today, today - 1, today - 2, today - 4, today - 5],
            3,
            false,
          ),
          (
            'future-dated clips do not extend it',
            <int>[today + 1, today + 2, today, today - 1],
            2,
            false,
          ),
          (
            'several clips on one day count once',
            <int>[today, today, today, today - 1],
            2,
            false,
          ),
        ];
    for (final (String why, List<int> history, int streak, bool atRisk)
        in rows) {
      final List<int> h = days(history);
      expect(
        JourneyMath.currentStreak(days: h, today: today),
        streak,
        reason: why,
      );
      if (history.isNotEmpty) {
        expect(
          JourneyMath.streakAtRisk(days: h, today: today),
          atRisk,
          reason: why,
        );
      }
    }

    // Across Europe's spring-forward (2026-03-29) and fall-back
    // (2026-10-25) and the US spring-forward (2026-03-08): three days in a
    // row are a run of three in any time zone.
    for (final LocalDay last in <LocalDay>[
      LocalDay(2026, 3, 30),
      LocalDay(2026, 10, 26),
      LocalDay(2026, 3, 9),
    ]) {
      final List<int> h = <int>[
        last.addDays(-2).epochDay,
        last.addDays(-1).epochDay,
        last.epochDay,
      ];
      expect(
        JourneyMath.currentStreak(days: h, today: last.epochDay),
        3,
        reason: '$last',
      );
    }
  });

  test('the longest streak is the longest run up to today, across months '
      'and years', () {
    final int today = d(2026, 9, 28);
    expect(
      JourneyMath.longestStreak(
        days: days(<int>[
          for (int i = 0; i < 48; i++) d(2025, 1, 10) + i,
          for (int i = 0; i < 12; i++) today - i,
        ]),
        today: today,
      ),
      48,
    );
    expect(
      JourneyMath.longestStreak(
        days: days(<int>[for (int i = 0; i < 5; i++) today + i]),
        today: today,
      ),
      1,
      reason: 'days after today are ignored',
    );
    expect(
      JourneyMath.longestStreak(
        days: days(<int>[for (int i = 0; i < 40; i++) d(2025, 12, 10) + i]),
        today: today,
      ),
      40,
    );
  });

  test('this month counts the recorded days of the month through today', () {
    final Set<int> skipped = <int>{9, 21, 25};
    final MonthProgress design = JourneyMath.thisMonth(
      days: days(<int>[
        for (int day = 1; day <= 28; day++)
          if (!skipped.contains(day)) d(2026, 9, day),
        d(2026, 8, 31), // the previous month is not counted
      ]),
      today: d(2026, 9, 28),
    );
    expect((design.recorded, design.elapsed), (25, 28));
    expect(design.ratio, closeTo(0.89, 0.01));

    final MonthProgress first = JourneyMath.thisMonth(
      days: days(<int>[d(2026, 9, 30)]),
      today: d(2026, 10, 1),
    );
    expect((first.recorded, first.elapsed), (0, 1));
  });
}
