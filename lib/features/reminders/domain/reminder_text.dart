import 'package:equatable/equatable.dart';

/// The reminder's title and body in the app's current language, resolved by
/// the caller: the reminders layer never localises. A locale change
/// re-plans, so scheduled reminders never keep the old language.
final class ReminderText extends Equatable {
  const ReminderText({required this.title, required this.body});

  final String title;
  final String body;

  @override
  List<Object?> get props => <Object?>[title, body];
}
