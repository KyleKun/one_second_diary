/// Composes an email in the user's mail app (`flutter_email_sender`), with a
/// `mailto:` fallback for devices without one. Used by "Report error" and
/// "Send an idea"; nothing is ever sent without the user.
abstract interface class EmailGateway {
  /// Opens the mail composer with [attachmentPaths] (e.g. the zipped logs).
  /// Throws when no mail app can take it. The error type is not part of the
  /// contract (the plugin throws a `PlatformException`): the caller treats
  /// ANY throw as "no mail app", logs it and falls back to [openMailto],
  /// never showing the error text.
  Future<void> send({
    required String recipient,
    required String subject,
    required String body,
    required List<String> attachmentPaths,
  });

  /// Opens a `mailto:` link (no attachments). Returns false when nothing
  /// could handle it; never throws.
  Future<bool> openMailto({
    required String recipient,
    required String subject,
    required String body,
  });
}
