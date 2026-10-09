import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/email_gateway.dart';

/// An email handed to a [FakeEmailGateway].
final class EmailDraft extends Equatable {
  const EmailDraft({
    required this.recipient,
    required this.subject,
    required this.body,
    required this.attachmentPaths,
  });

  final String recipient;
  final String subject;
  final String body;
  final List<String> attachmentPaths;

  @override
  List<Object?> get props => <Object?>[
    recipient,
    subject,
    body,
    attachmentPaths,
  ];
}

/// An [EmailGateway] that records drafts.
///
/// `send` records into [sent], then throws [sendError] when set
/// (no mail app). `openMailto` records into [mailtos] (no attachments) and
/// answers [mailtoResult].
class FakeEmailGateway extends Fake implements EmailGateway {
  final List<EmailDraft> sent = <EmailDraft>[];
  final List<EmailDraft> mailtos = <EmailDraft>[];
  Object? sendError;
  bool mailtoResult = true;

  @override
  Future<void> send({
    required String recipient,
    required String subject,
    required String body,
    required List<String> attachmentPaths,
  }) async {
    sent.add(
      EmailDraft(
        recipient: recipient,
        subject: subject,
        body: body,
        attachmentPaths: List<String>.unmodifiable(attachmentPaths),
      ),
    );
    final Object? error = sendError;
    if (error != null) throw error;
  }

  @override
  Future<bool> openMailto({
    required String recipient,
    required String subject,
    required String body,
  }) async {
    mailtos.add(
      EmailDraft(
        recipient: recipient,
        subject: subject,
        body: body,
        attachmentPaths: const <String>[],
      ),
    );
    return mailtoResult;
  }
}
