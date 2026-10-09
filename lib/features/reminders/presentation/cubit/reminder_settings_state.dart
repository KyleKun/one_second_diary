import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/permissions/access_outcome.dart';
import 'package:one_second_diary/features/settings/domain/reminder_time.dart';

/// What the reminder settings are doing.
///
/// Every change starts with [requesting] or [saving], so each refusal is a
/// new transition to [saveFailed] that a `BlocListener` sees, however many
/// come in a row.
enum ReminderSettingsStatus {
  /// The page shows what is stored.
  ready,

  /// The user turned the reminder on and the system is asked for the
  /// permission to post it.
  requesting,

  /// A change is being stored.
  saving,

  /// The phone refused to store a change; nothing changed.
  saveFailed,
}

/// What the Settings "Notifications" row says about the reminder.
enum ReminderSummary {
  /// The reminder is off: "Off".
  off,

  /// The reminder is on but the phone won't show it: "Blocked".
  blocked,

  /// The reminder is on: its time.
  on,
}

/// The daily reminder as the user set it, and whether the phone lets the
/// app post it.
final class ReminderSettingsState extends Equatable {
  const ReminderSettingsState({
    required this.enabled,
    required this.persistent,
    required this.time,
    this.access,
    this.refused = false,
    this.status = ReminderSettingsStatus.ready,
  });

  /// The stored "Daily reminder" switch (`activatedNotification`).
  final bool enabled;

  /// "Persistent notification" (`persistentNotification`, Android only).
  final bool persistent;

  /// When the reminder fires.
  final ReminderTime time;

  /// Whether the phone lets the app post notifications; null until it was
  /// checked (only while the reminder is on, or after the user asked).
  final AccessOutcome? access;

  /// The user's last attempt to turn the reminder on was refused by the
  /// system: the page explains it even though the switch is off.
  final bool refused;

  final ReminderSettingsStatus status;

  /// The switch as drawn: on while the permission is being asked, so a
  /// refusal animates it back off.
  bool get switchOn => enabled || status == ReminderSettingsStatus.requesting;

  /// Whether the page shows the blocked banner: the phone won't post the
  /// reminder the user wants.
  bool get blocked =>
      access != null && access != AccessOutcome.granted && (enabled || refused);

  /// What the Settings row shows.
  ReminderSummary get summary => !enabled
      ? ReminderSummary.off
      : blocked
      ? ReminderSummary.blocked
      : ReminderSummary.on;

  ReminderSettingsState copyWith({
    bool? enabled,
    bool? persistent,
    ReminderTime? time,
    AccessOutcome? access,
    bool? refused,
    ReminderSettingsStatus? status,
  }) => ReminderSettingsState(
    enabled: enabled ?? this.enabled,
    persistent: persistent ?? this.persistent,
    time: time ?? this.time,
    access: access ?? this.access,
    refused: refused ?? this.refused,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => <Object?>[
    enabled,
    persistent,
    time,
    access,
    refused,
    status,
  ];
}
