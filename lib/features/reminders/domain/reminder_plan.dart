import 'package:one_second_diary/features/reminders/domain/planned_reminder.dart';

/// What the reminders should look like after a re-plan (`ReminderPlanner`).
final class ReminderPlan {
  const ReminderPlan({required this.reminders, this.dueTodayId});

  /// The notifications to schedule, soonest first. Every instant is in the
  /// future and no day in it is recorded.
  final List<PlannedReminder> reminders;

  /// Today's reminder id when its time has passed and today is not recorded
  /// yet: it may be on screen, and a persistent one must stay until today
  /// is recorded, so a re-plan leaves this id alone. Null otherwise; then
  /// today's reminder, if any, is in [reminders] or must go.
  final int? dueTodayId;
}
