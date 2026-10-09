import 'package:equatable/equatable.dart';

/// The user tapped one of the app's notifications.
final class NotificationTap extends Equatable {
  const NotificationTap({required this.id});

  /// The tapped notification's id, when the OS reports it.
  final int? id;

  @override
  List<Object?> get props => <Object?>[id];
}
