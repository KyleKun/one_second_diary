import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';

/// One month of the picker: its clips by day, then ordinal.
final class ClipMonth {
  const ClipMonth({
    required this.year,
    required this.month,
    required this.clips,
  });

  final int year;

  /// 1–12.
  final int month;

  /// The month's visible clips in play order; never empty.
  final List<ClipRef> clips;

  LocalDay get first => LocalDay(year, month, 1);

  LocalDay get last =>
      (month == 12 ? LocalDay(year + 1, 1, 1) : LocalDay(year, month + 1, 1))
          .addDays(-1);
}

/// A profile's clips by month for the picker: the newest month first, as
/// the picker opens on it; within a month the days in order, as drawn.
abstract final class ClipMonths {
  static final Expando<List<ClipMonth>> _built = Expando<List<ClipMonth>>(
    'ClipMonths',
  );

  /// The months of [index]. Made once per snapshot (one pass over its
  /// days), so the picker may ask for them in every build.
  static List<ClipMonth> of(ClipIndex index) =>
      _built[index] ??= List<ClipMonth>.unmodifiable(_group(index));

  static Iterable<ClipMonth> _group(ClipIndex index) {
    final List<ClipMonth> months = <ClipMonth>[];
    final List<int> days = index.epochDays;
    int next = 0;
    while (next < days.length) {
      final LocalDay first = LocalDay.fromEpochDay(days[next]);
      final List<ClipRef> clips = <ClipRef>[];
      for (; next < days.length; next++) {
        final LocalDay day = LocalDay.fromEpochDay(days[next]);
        if (day.year != first.year || day.month != first.month) break;
        clips.addAll(index.clipsOn(day));
      }
      months.add(
        ClipMonth(
          year: first.year,
          month: first.month,
          clips: List<ClipRef>.unmodifiable(clips),
        ),
      );
    }
    return months.reversed;
  }
}
