import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:one_second_diary/core/platform/email_gateway.dart';
import 'package:one_second_diary/core/platform/url_gateway.dart';

/// [EmailGateway] over `flutter_email_sender` (the composer, which can
/// attach files) and a [UrlGateway] (the `mailto:` fallback).
///
/// Android needs the `SENDTO mailto` `<queries>` entry in the manifest for
/// both. On iOS the composer is the system Mail app, which throws when no
/// account is set up: that is when the caller falls back to [openMailto].
final class EmailSenderGateway implements EmailGateway {
  EmailSenderGateway({required this._urls});

  final UrlGateway _urls;

  @override
  Future<void> send({
    required String recipient,
    required String subject,
    required String body,
    required List<String> attachmentPaths,
  }) => FlutterEmailSender.send(
    Email(
      recipients: <String>[recipient],
      subject: subject,
      body: body,
      attachmentPaths: attachmentPaths,
    ),
  );

  /// Percent-encodes the subject and body by hand: `Uri`'s
  /// `queryParameters` would encode spaces as `+`, which mail apps show
  /// literally ("[One+Second+Diary…").
  @override
  Future<bool> openMailto({
    required String recipient,
    required String subject,
    required String body,
  }) => _urls.open(
    Uri(
      scheme: 'mailto',
      path: recipient,
      query:
          'subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body)}',
    ),
  );
}
