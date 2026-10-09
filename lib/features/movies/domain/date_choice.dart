import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';

/// The "Choose dates" sheet's choice: the first day picked ([from]), the last
/// ([to]) and the month its grid shows ([shown]).
final class DateChoice extends Equatable {
  const DateChoice({this.from, this.to, required this.shown})
    : assert(
        from != null || to == null,
        'the last day is only picked after the first',
      );

  final LocalDay? from;
  final LocalDay? to;

  /// The month the grid shows.
  final DiaryMonth shown;

  /// Which end the next tap sets.
  DateEnd get next => from == null || to != null ? DateEnd.from : DateEnd.to;

  /// The days picked, once both ends are; null until then.
  DayRange? get range {
    final LocalDay? from = this.from;
    final LocalDay? to = this.to;
    return from == null || to == null ? null : DayRange(first: from, last: to);
  }

  DateChoice copyWith({
    LocalDay? from,
    LocalDay? to,
    DiaryMonth? shown,
    bool clearFrom = false,
    bool clearTo = false,
  }) => DateChoice(
    from: clearFrom ? null : from ?? this.from,
    to: clearTo || clearFrom ? null : to ?? this.to,
    shown: shown ?? this.shown,
  );

  @override
  List<Object?> get props => <Object?>[from, to, shown];
}

/// An end of a [DateChoice].
enum DateEnd { from, to }
