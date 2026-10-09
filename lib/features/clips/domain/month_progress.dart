import 'package:equatable/equatable.dart';

/// "25 of 28 days" (Diary) and "This month 25 / 28" (Journey): the recorded
/// days of a month counted through today, out of its elapsed days.
final class MonthProgress extends Equatable {
  const MonthProgress({required this.recorded, required this.elapsed});

  /// Distinct days with at least one clip, from the 1st through today.
  final int recorded;

  /// Days of the month through today, today included: today's day of month
  /// for the current month, every day for a past month, 0 for a future one.
  final int elapsed;

  /// [recorded] / [elapsed]; 0 when no day has elapsed.
  double get ratio => elapsed == 0 ? 0 : recorded / elapsed;

  @override
  List<Object?> get props => <Object?>[recorded, elapsed];
}
