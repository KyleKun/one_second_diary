import 'package:equatable/equatable.dart';

/// A notification scheduled with the OS and not yet shown.
final class PendingNotification extends Equatable {
  const PendingNotification({
    required this.id,
    required this.title,
    required this.body,
  });

  final int id;
  final String? title;
  final String? body;

  @override
  List<Object?> get props => <Object?>[id, title, body];
}
