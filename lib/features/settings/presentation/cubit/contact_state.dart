import 'package:equatable/equatable.dart';

/// What the user wants to tell the developer.
enum ContactTopic {
  /// "Something isn't working": the logs go with the mail.
  problem,

  /// "I have an idea".
  idea,
}

/// Where the last contact request is. Every request starts with
/// [preparing], so each [noMailApp] is a new transition a `BlocListener`
/// sees.
enum ContactStatus {
  ready,

  /// The mail is being prepared (the logs zipped, for a problem).
  preparing,

  /// The user's mail app opened with the mail.
  mailOpened,

  /// Nothing on the phone could open a mail.
  noMailApp,
}

/// The Contact dialog's request.
final class ContactState extends Equatable {
  const ContactState({this.status = ContactStatus.ready, this.topic});

  final ContactStatus status;

  /// What is being sent, while [ContactStatus.preparing] and after.
  final ContactTopic? topic;

  bool get isBusy => status == ContactStatus.preparing;

  @override
  List<Object?> get props => <Object?>[status, topic];
}
