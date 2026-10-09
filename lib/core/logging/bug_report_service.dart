import 'dart:io';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/app_info_gateway.dart';
import 'package:one_second_diary/core/platform/archive_gateway.dart';
import 'package:one_second_diary/core/platform/email_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

/// How a contact request reached the user's mail app, so the screen can
/// say something useful when none did. Never carries error text: raw
/// exception text is for the log only.
enum BugReportOutcome {
  /// The mail composer opened (with the zipped logs, for a report).
  composerOpened,

  /// No composer took it; a `mailto:` link opened instead (no attachment).
  mailtoOpened,

  /// Nothing on the device could open an email.
  noMailApp,
}

/// "Report error" (on every failure surface and Contact → "Something isn't
/// working") and Contact → "I have an idea". Nothing is sent without the
/// user: both only open their mail app.
///
/// A report flushes the log, zips `AppPaths.logsDir` to
/// `AppPaths.logsZipPath`, opens the composer to the developer, and falls
/// back to a `mailto:` link on ANY failure (no mail account on iOS, zip
/// failure, missing plugin).
///
/// A plain class (not final), so cubit tests can fake it.
class BugReportService {
  /// [appInfo] gives the app version for the subjects, read at runtime (so
  /// the subject never shows a stale version), but only when a report is
  /// made: the service is built at launch, and nothing may wait on the
  /// platform before the first frame.
  ///
  /// [logsUnavailable] is the note a report without its logs ends with
  /// (`contactLogsUnavailable`, "(logs unavailable)", in the app language
  /// when the report is made).
  BugReportService({
    required this._logger,
    required this._paths,
    required this._archive,
    required this._email,
    required this._appInfo,
    required this._logsUnavailable,
  });

  /// Where every report and idea goes.
  static const String developerEmail = 'kylekundev@gmail.com';

  static const String _tag = 'BUG_REPORT';

  final AppLogger _logger;
  final AppPaths _paths;
  final ArchiveGateway _archive;
  final EmailGateway _email;
  final AppInfoGateway _appInfo;
  final String Function() _logsUnavailable;

  /// The subject the owner filters reports by: English in every language.
  Future<String> _errorReportSubject() async =>
      '[One Second Diary - v${await _appInfo.version()}] App Error Report';

  /// The subject of Contact → "I have an idea".
  Future<String> _feedbackSubject() async =>
      '[One Second Diary - v${await _appInfo.version()}] Feedback';

  /// Opens the mail composer with the zipped logs. [body] is the localised
  /// `errorMailBody` text, resolved by the caller. When the logs can't be
  /// attached (no composer, no zip), a `mailto:` link opens instead, and
  /// its body says the logs are missing.
  Future<BugReportOutcome> reportError({required String body}) async {
    try {
      _logger.info(_tag, 'Sending logs to the developer');
      await _logger.flush();
      // Older installs wrote the zip inside the logs folder: delete it there
      // too, or it would end up inside the new zip.
      await _deleteIfPresent('${_paths.logsDir}/logs.zip');
      await _deleteIfPresent(_paths.logsZipPath);
      await _archive.zipFilesIn(
        sourceDir: _paths.logsDir,
        zipPath: _paths.logsZipPath,
      );
      await _email.send(
        recipient: developerEmail,
        subject: await _errorReportSubject(),
        body: body,
        attachmentPaths: <String>[_paths.logsZipPath],
      );
      return BugReportOutcome.composerOpened;
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not attach the logs, opening a mailto link instead',
        error: error,
        stackTrace: stackTrace,
      );
      return _openMailto(
        subject: await _errorReportSubject(),
        body: '$body\n\n${_logsUnavailable()}',
      );
    }
  }

  /// Opens a `mailto:` link to the developer with the Feedback subject and
  /// no attachment. A link opens the user's default mail app, where the
  /// composer is tied to the system Mail app on iOS. [body] is resolved by
  /// the caller (may be empty).
  Future<BugReportOutcome> shareIdea({required String body}) async {
    _logger.info(_tag, 'Opening an email to share an idea');
    return _openMailto(subject: await _feedbackSubject(), body: body);
  }

  Future<BugReportOutcome> _openMailto({
    required String subject,
    required String body,
  }) async {
    final bool opened = await _email.openMailto(
      recipient: developerEmail,
      subject: subject,
      body: body,
    );
    if (opened) return BugReportOutcome.mailtoOpened;
    _logger.warning(_tag, 'No app could open a mailto link');
    return BugReportOutcome.noMailApp;
  }

  static Future<void> _deleteIfPresent(String path) async {
    try {
      await File(path).delete();
    } on PathNotFoundException {
      // Nothing to delete.
    }
  }
}
