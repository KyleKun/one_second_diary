import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:timezone/timezone.dart' as tz;

/// One reminder of a plan: notification [id] for [day], shown at [at].
final class PlannedReminder extends Equatable {
  const PlannedReminder({
    required this.id,
    required this.day,
    required this.at,
  });

  final int id;
  final LocalDay day;
  final tz.TZDateTime at;

  @override
  List<Object?> get props => <Object?>[id, day, at];
}
