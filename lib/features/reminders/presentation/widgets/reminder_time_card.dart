import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/reminders/presentation/reminder_time_label.dart';
import 'package:one_second_diary/features/reminders/presentation/widgets/reminder_time_text.dart';
import 'package:one_second_diary/shared/widgets/buttons/outlined_pill_button.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The Notifications page's time card: "Remind me at", the big time, and
/// the outlined "Change time" pill.
class ReminderTimeCard extends StatelessWidget {
  const ReminderTimeCard({
    super.key,
    required this.label,
    required this.onChange,
    this.changeKey,
  });

  final ReminderTimeLabel label;

  /// "Change time", or a tap on the time.
  final VoidCallback? onChange;

  /// The key of the "Change time" pill.
  final Key? changeKey;

  static const double _gap = 14;

  @override
  Widget build(BuildContext context) => OsdCard(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: _gap,
      children: <Widget>[
        Text(
          Strings.scheduleTime,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: context.typography.label13.copyWith(color: context.colors.mu),
        ),
        ReminderTimeText(label: label, onTap: onChange),
        OutlinedPillButton(
          key: changeKey,
          icon: OsdIcons.schedule,
          label: Strings.notificationsChangeTime,
          onPressed: onChange,
        ),
      ],
    ),
  );
}
