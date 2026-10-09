import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/month_progress.dart';
import 'package:one_second_diary/features/clips/domain/sorted_epoch_days.dart';

/// The day arithmetic behind the Journey tab.
///
/// Every function takes the recorded days as sorted, unique epoch days
/// (`ClipIndex.epochDays`) and today as an epoch day, so a DST change can
/// never make a day 23 or 25 hours long. Several clips on one day count
/// once: the index de-duplicates days.
abstract final class JourneyMath {
  /// Consecutive recorded days ending today when today is recorded, else
  /// ending yesterday: the streak stays alive until today is over, so "not
  /// yet recorded today" never shows 0 at breakfast. 0 when neither today
  /// nor yesterday is recorded. Days after [today] (a wrong clock) never
  /// count.
  static int currentStreak({required List<int> days, required int today}) {
    final int anchor;
    if (days.containsDay(today)) {
      anchor = today;
    } else if (days.containsDay(today - 1)) {
      anchor = today - 1;
    } else {
      return 0;
    }
    int i = days.indexAtOrAfter(anchor);
    int streak = 1;
    while (i > 0 && days[i - 1] == days[i] - 1) {
      streak++;
      i--;
    }
    return streak;
  }

  /// Whether today still needs a clip to keep the streak ("record today to
  /// keep it").
  static bool streakAtRisk({required List<int> days, required int today}) =>
      !days.containsDay(today) && days.containsDay(today - 1);

  /// The longest run of consecutive recorded days, ignoring days after
  /// [today].
  static int longestStreak({required List<int> days, required int today}) {
    int best = 0;
    int run = 0;
    int? previous;
    for (final int day in days) {
      if (day > today) break;
      run = day - 1 == previous ? run + 1 : 1;
      if (run > best) best = run;
      previous = day;
    }
    return best;
  }

  /// Recorded days from the 1st of today's month through today, out of
  /// today's day of month ("25 / 28" on September 28).
  static MonthProgress thisMonth({
    required List<int> days,
    required int today,
  }) {
    final LocalDay day = LocalDay.fromEpochDay(today);
    final int first = LocalDay(day.year, day.month, 1).epochDay;
    return MonthProgress(
      recorded: days.countBetween(first, today),
      elapsed: day.day,
    );
  }
}
