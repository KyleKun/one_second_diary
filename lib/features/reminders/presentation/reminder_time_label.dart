import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/display_text.dart';
import 'package:one_second_diary/features/settings/domain/reminder_time.dart';

/// The reminder time as the Notifications page draws it: the digits ([time])
/// and, in a 12-hour format, the day period ([before] or [after], as the app
/// language places it). [spoken] is the whole time for screen readers and the
/// Settings row's value.
///
/// [time] goes through `DisplayText.safe` (Yusei Magic lacks the narrow
/// no-break space).
final class ReminderTimeLabel extends Equatable {
  const ReminderTimeLabel({
    required this.time,
    required this.spoken,
    this.before,
    this.after,
  });

  factory ReminderTimeLabel.of(
    ReminderTime reminder, {
    required MaterialLocalizations localizations,
    required bool alwaysUse24HourFormat,
  }) {
    final TimeOfDay time = TimeOfDay(
      hour: reminder.hour,
      minute: reminder.minute,
    );
    final String spoken = localizations.formatTimeOfDay(
      time,
      alwaysUse24HourFormat: alwaysUse24HourFormat,
    );
    final TimeOfDayFormat format = localizations.timeOfDayFormat(
      alwaysUse24HourFormat: alwaysUse24HourFormat,
    );
    final String digits =
        '${localizations.formatHour(time, alwaysUse24HourFormat: alwaysUse24HourFormat)}'
        ':${localizations.formatMinute(time)}';
    final String period = time.period == DayPeriod.am
        ? localizations.anteMeridiemAbbreviation
        : localizations.postMeridiemAbbreviation;
    return switch (format) {
      TimeOfDayFormat.h_colon_mm_space_a => ReminderTimeLabel(
        time: DisplayText.safe(digits),
        after: period,
        spoken: spoken,
      ),
      TimeOfDayFormat.a_space_h_colon_mm => ReminderTimeLabel(
        time: DisplayText.safe(digits),
        before: period,
        spoken: spoken,
      ),
      _ => ReminderTimeLabel(time: DisplayText.safe(spoken), spoken: spoken),
    };
  }

  /// The digits, in the display font.
  final String time;

  /// A day period drawn before [time] ("上午"), or null.
  final String? before;

  /// A day period drawn after [time] ("PM"), or null.
  final String? after;

  /// The whole time as the language writes it.
  final String spoken;

  @override
  List<Object?> get props => <Object?>[time, before, after, spoken];
}
