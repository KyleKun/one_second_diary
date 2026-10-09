import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/time/local_day.dart';

/// A closed range of calendar days, [first] through [last].
///
/// Ranges are whole calendar days compared as `LocalDay.epochDay`, never
/// instants: subtracting `Duration(days: n)` from `DateTime.now()` picks one
/// day too many in a window containing a spring-forward. The range is empty
/// when [last] is before [first].
final class DayRange extends Equatable {
  const DayRange({required this.first, required this.last});

  final LocalDay first;
  final LocalDay last;

  bool get isEmpty => last.isBefore(first);

  @override
  List<Object?> get props => <Object?>[first, last];

  @override
  String toString() => 'DayRange(${first.fileStem}..${last.fileStem})';
}
