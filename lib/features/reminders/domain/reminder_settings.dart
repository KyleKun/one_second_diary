import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/settings/domain/reminder_time.dart';

/// The user's reminder choices, the planner's input. Stored in four keys,
/// which `SettingsRepository` owns (`remindersEnabled`,
/// `persistentReminder`, `reminderTime`).
final class ReminderSettings extends Equatable {
  const ReminderSettings({
    required this.enabled,
    required this.persistent,
    required this.time,
  });

  /// The "Daily reminder" switch (`activatedNotification`).
  final bool enabled;

  /// "Persistent notification" (`persistentNotification`).
  final bool persistent;

  /// The reminder time (`scheduledTimeHour`, `scheduledTimeMinute`): the
  /// `SettingsRepository.reminderTime` value as it is.
  final ReminderTime time;

  int get hour => time.hour;
  int get minute => time.minute;

  @override
  List<Object?> get props => <Object?>[enabled, persistent, time];
}
