import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';

/// A calendar month, the page the Diary shows: [year] and [month] (1–12).
///
/// It knows its days and how they sit in a 7-column grid for a locale whose
/// week starts on `firstWeekday` (`MaterialLocalizations.firstDayOfWeekIndex`:
/// 0 is Sunday). Weekdays are computed in UTC, so no DST change moves a day.
final class DiaryMonth extends Equatable implements Comparable<DiaryMonth> {
  const DiaryMonth(this.year, this.month)
    : assert(month >= 1 && month <= 12, 'month must be 1-12');

  /// The month [day] falls in.
  DiaryMonth.of(LocalDay day) : this(day.year, day.month);

  final int year;

  /// 1–12.
  final int month;

  LocalDay get first => LocalDay(year, month, 1);

  LocalDay get last => LocalDay(year, month, dayCount);

  /// Days in the month (28–31).
  int get dayCount => DateTime.utc(year, month + 1, 0).day;

  DayRange get range => DayRange(first: first, last: last);

  DiaryMonth get previous =>
      month == 1 ? DiaryMonth(year - 1, 12) : DiaryMonth(year, month - 1);

  DiaryMonth get next =>
      month == 12 ? DiaryMonth(year + 1, 1) : DiaryMonth(year, month + 1);

  bool contains(LocalDay day) => day.year == year && day.month == month;

  bool isBefore(DiaryMonth other) => compareTo(other) < 0;

  bool isAfter(DiaryMonth other) => compareTo(other) > 0;

  /// Empty slots before day 1 in a week that starts on [firstWeekday]
  /// (0 = Sunday … 6 = Saturday).
  int leadingBlanks({required int firstWeekday}) {
    // DateTime.weekday is 1 (Monday) … 7 (Sunday); % 7 makes Sunday 0.
    final int weekdayOfFirst = DateTime.utc(year, month).weekday % 7;
    return (weekdayOfFirst - firstWeekday) % 7;
  }

  /// Rows the month fills in the grid: 4, 5 or 6.
  int weekCount({required int firstWeekday}) =>
      (leadingBlanks(firstWeekday: firstWeekday) + dayCount + 6) ~/ 7;

  int get _ordinal => year * 12 + month - 1;

  @override
  int compareTo(DiaryMonth other) => _ordinal.compareTo(other._ordinal);

  @override
  List<Object?> get props => <Object?>[year, month];

  @override
  String toString() => 'DiaryMonth($year-$month)';
}
