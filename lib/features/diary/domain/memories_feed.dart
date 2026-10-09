import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/sorted_epoch_days.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';

/// One row of the [MemoriesFeed]: a month's header or one of its days.
sealed class MemoriesRow extends Equatable {
  const MemoriesRow();
}

/// The header of [month] ("September 2026", "25 of 28 days", Make movie).
final class MemoriesMonthRow extends MemoriesRow {
  const MemoriesMonthRow(this.month);

  final DiaryMonth month;

  @override
  List<Object?> get props => <Object?>[month];
}

/// The cards of recorded [days], newest first: one [day], or side by side
/// in a feed of several columns (tablets).
final class MemoriesDayRow extends MemoriesRow {
  MemoriesDayRow(LocalDay day) : days = <LocalDay>[day];

  const MemoriesDayRow.of(this.days) : assert(days.length > 0, 'a day');

  final List<LocalDay> days;

  /// The row's first (newest) day.
  LocalDay get day => days.first;

  @override
  List<Object?> get props => <Object?>[...days];
}

/// The Memories feed of one snapshot: every month with a clip, newest
/// first, each heading its recorded days, newest first; months without
/// clips are left out.
///
/// A list of rows the feed's lazy list reads by index, so it builds only
/// the rows on screen. Building it costs one binary search per month the
/// diary spans, never a pass over the clips; a row is two binary searches.
/// It is built once per snapshot and number of [columns] ([of]): a row
/// holds that many days of one month side by side (two on tablets).
final class MemoriesFeed {
  MemoriesFeed._(
    this.columns,
    this._days,
    this._months,
    this._rowStarts,
    this._firstDays,
    this._lastDays,
  );

  /// The feed of [index] in [columns], built on first use and kept with
  /// it.
  factory MemoriesFeed.of(ClipIndex index, {int columns = 1}) {
    assert(columns > 0, 'a column at least');
    final Expando<MemoriesFeed> built = _built[columns] ??=
        Expando<MemoriesFeed>();
    return built[index] ??= MemoriesFeed._build(index, columns);
  }

  factory MemoriesFeed._build(ClipIndex index, int columns) {
    final List<int> days = index.epochDays;
    final List<DiaryMonth> months = <DiaryMonth>[];
    final List<int> rowStarts = <int>[];
    final List<int> firstDays = <int>[];
    final List<int> lastDays = <int>[];
    final LocalDay? first = index.firstDay;
    final LocalDay? last = index.lastDay;
    if (first != null && last != null) {
      final DiaryMonth oldest = DiaryMonth.of(first);
      int rows = 0;
      for (
        DiaryMonth month = DiaryMonth.of(last);
        !month.isBefore(oldest);
        month = month.previous
      ) {
        final int from = days.indexAtOrAfter(month.first.epochDay);
        final int until = days.indexAtOrAfter(month.last.epochDay + 1);
        if (until == from) continue;
        months.add(month);
        rowStarts.add(rows);
        firstDays.add(from);
        lastDays.add(until - 1);
        rows += 1 + (until - from + columns - 1) ~/ columns;
      }
    }
    return MemoriesFeed._(
      columns,
      days,
      months,
      rowStarts,
      firstDays,
      lastDays,
    );
  }

  static final Map<int, Expando<MemoriesFeed>> _built =
      <int, Expando<MemoriesFeed>>{};

  /// How many days a row holds.
  final int columns;

  /// The index's recorded days (epoch days, oldest first).
  final List<int> _days;

  /// The months shown, newest first.
  final List<DiaryMonth> _months;

  /// The row of each month's header.
  final List<int> _rowStarts;

  /// The position in [_days] of each month's oldest day.
  final List<int> _firstDays;

  /// The position in [_days] of each month's newest day.
  final List<int> _lastDays;

  /// Rows: a header per month, then its recorded days, [columns] a row.
  int get length => _months.isEmpty
      ? 0
      : _rowStarts.last + 1 + _rowsOfDays(_months.length - 1);

  bool get isEmpty => _months.isEmpty;

  /// Row [row] (0 ≤ [row] < [length]).
  MemoriesRow operator [](int row) {
    final int month = _monthOfRow(row);
    final int offset = row - _rowStarts[month];
    if (offset == 0) return MemoriesMonthRow(_months[month]);
    final int newest = _lastDays[month] - (offset - 1) * columns;
    final int oldest = newest - columns + 1;
    return MemoriesDayRow.of(<LocalDay>[
      for (
        int position = newest;
        position >= oldest && position >= _firstDays[month];
        position--
      )
        LocalDay.fromEpochDay(_days[position]),
    ]);
  }

  /// How many rows [month]'s days take.
  int _rowsOfDays(int month) =>
      (_lastDays[month] - _firstDays[month] + columns) ~/ columns;

  /// The month row [row] belongs to.
  DiaryMonth monthAt(int row) => _months[_monthOfRow(row)];

  /// The row of [day]'s card; null when it has no clip.
  int? indexOfDay(LocalDay day) {
    final int position = _days.indexAtOrAfter(day.epochDay);
    if (position >= _days.length || _days[position] != day.epochDay) {
      return null;
    }
    final DiaryMonth target = DiaryMonth.of(day);
    int low = 0;
    int high = _months.length - 1;
    while (low <= high) {
      final int middle = (low + high) >> 1;
      final int order = _months[middle].compareTo(target);
      if (order == 0) {
        return _rowStarts[middle] +
            1 +
            (_lastDays[middle] - position) ~/ columns;
      }
      // Newest first: a later month sits before the target.
      if (order > 0) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return null;
  }

  /// The month whose rows hold [row]: the last header at or before it.
  int _monthOfRow(int row) {
    RangeError.checkValidIndex(row, this, 'row', length);
    int low = 0;
    int high = _rowStarts.length - 1;
    while (low < high) {
      final int middle = (low + high + 1) >> 1;
      if (_rowStarts[middle] <= row) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low;
  }
}
