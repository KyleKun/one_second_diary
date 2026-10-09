import 'package:equatable/equatable.dart';

/// The name and description of the app's Android notification channel, in
/// the app's current language: Android shows them in the app's
/// notification settings. The caller resolves them (`Strings`); the
/// gateway never localises, as with `ReminderText`.
final class NotificationChannelText extends Equatable {
  const NotificationChannelText({
    required this.name,
    required this.description,
  });

  final String name;
  final String description;

  @override
  List<Object?> get props => <Object?>[name, description];
}
