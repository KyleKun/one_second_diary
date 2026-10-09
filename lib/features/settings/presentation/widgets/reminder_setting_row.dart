import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/reminders/presentation/cubit/reminder_settings_cubit.dart';
import 'package:one_second_diary/features/reminders/presentation/cubit/reminder_settings_state.dart';
import 'package:one_second_diary/features/settings/domain/reminder_time.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The Settings tab's "Notifications" row: the reminder time, "Off", or
/// "Blocked" in RED when the phone won't show the reminder.
///
/// The time follows the phone's 12/24-hour setting in the app language
/// ("20:00", "8:00 PM").
class ReminderSettingRow extends StatelessWidget {
  const ReminderSettingRow({super.key});

  @override
  Widget build(BuildContext context) {
    final (ReminderSummary summary, ReminderTime time) = context.select(
      (ReminderSettingsCubit cubit) => (cubit.state.summary, cubit.state.time),
    );
    final OsdColors colors = context.colors;
    final Widget row = OsdListRow(
      title: Strings.notifications,
      icon: OsdIcons.notifications,
      // The leading icon keeps MU when the value turns RED (below).
      iconColor: colors.mu,
      value: switch (summary) {
        ReminderSummary.off => Strings.settingsValueOff,
        ReminderSummary.blocked => Strings.settingsValueBlocked,
        ReminderSummary.on => MaterialLocalizations.of(context).formatTimeOfDay(
          TimeOfDay(hour: time.hour, minute: time.minute),
          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        ),
      },
      trailing: const OsdRowTrailing.chevron(),
      onTap: () => AppRoute.notifications.push<void>(context),
    );
    // `OsdListRow` draws its value in MU; "Blocked" is RED. The
    // theme wraps the row in every state, so the row is never rebuilt from
    // scratch when the state changes.
    final ThemeData theme = Theme.of(context);
    return Theme(
      data: summary != ReminderSummary.blocked
          ? theme
          : theme.copyWith(
              extensions: theme.extensions.values.map(
                (ThemeExtension<dynamic> extension) => extension is OsdColors
                    ? extension.copyWith(mu: extension.red)
                    : extension,
              ),
            ),
      child: row,
    );
  }
}
