import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/logging/bug_report_service.dart';
import 'package:one_second_diary/core/logging/log_session.dart';
import 'package:one_second_diary/core/platform/file_log_sink.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

import '../../shared/fakes/fake_app_info_gateway.dart';
import '../../support/support.dart';
import '../../support/track_1d/fake_archive_gateway.dart';

void main() {
  late AppPaths paths;
  late FakeClock clock;
  late AppLogger logger;
  late FakeArchiveGateway archive;
  late FakeEmailGateway email;
  late FakeAppInfoGateway appInfo;
  late BugReportService service;

  setUp(() async {
    paths = await createTestPaths();
    clock = FakeClock(DateTime(2024, 1, 5, 10));
    // The real session file, so the zip sees what is really on disk.
    final FileLogSink sink = await LogSession(
      paths: paths,
      prefs: await openLegacyPrefs(freshInstallPrefs),
      clock: clock,
    ).open();
    addTearDown(sink.close);
    logger = AppLogger(sink: sink, clock: clock, isVerboseEnabled: () => false);
    archive = FakeArchiveGateway();
    email = FakeEmailGateway();
    appInfo = FakeAppInfoGateway();
    service = BugReportService(
      logger: logger,
      paths: paths,
      archive: archive,
      email: email,
      appInfo: appInfo,
      logsUnavailable: () => '(logs unavailable)',
    );
  });

  group('reportError', () {
    test('opens the mail composer to the developer with the logs folder '
        'zipped, every line logged so far, and never a stale logs.zip v1.x '
        'left there', () async {
      await File('${paths.logsDir}/logs.zip').writeAsString('stale');
      logger.info('SAVE', 'Save failed');

      final BugReportOutcome outcome = await service.reportError(
        body: 'Describe what happened',
      );

      expect(outcome, BugReportOutcome.composerOpened);
      expect(email.sent, <EmailDraft>[
        EmailDraft(
          recipient: 'kylekundev@gmail.com',
          subject: '[One Second Diary - v2.0.0] App Error Report',
          body: 'Describe what happened',
          attachmentPaths: <String>[paths.logsZipPath],
        ),
      ]);
      final FakeZip zip = archive.zips.single;
      expect(zip.sourceDir, paths.logsDir);
      expect(zip.zipPath, paths.logsZipPath);
      expect(zip.entries.keys, <String>['2024-01-05_10-00-00.txt']);
      expect(
        zip.entries['2024-01-05_10-00-00.txt'],
        contains('[INFO] 2024-01-05 10:00:00.000: [SAVE] Save failed\n'),
      );
    });

    // The service is built at launch but the version is asked for per report; a version
    // read at build time would name 2.0.0.
    test('names the version the platform reports when the report is '
        'made', () async {
      appInfo.appVersion = '2.0.1';

      await service.reportError(body: 'body');

      expect(
        email.sent.single.subject,
        '[One Second Diary - v2.0.1] App Error Report',
      );
    });

    test('falls back to a mailto link when no mail app takes the zip, says '
        'the logs are missing and logs why; reports noMailApp when the link '
        'cannot be opened either', () async {
      email.sendError = Exception('No mail account');

      final BugReportOutcome outcome = await service.reportError(
        body: 'Describe what happened',
      );
      await logger.flush();

      expect(outcome, BugReportOutcome.mailtoOpened);
      expect(email.mailtos, <EmailDraft>[
        const EmailDraft(
          recipient: 'kylekundev@gmail.com',
          subject: '[One Second Diary - v2.0.0] App Error Report',
          body: 'Describe what happened\n\n(logs unavailable)',
          attachmentPaths: <String>[],
        ),
      ]);
      expect(
        await File('${paths.logsDir}/2024-01-05_10-00-00.txt').readAsString(),
        contains(
          '[WARNING] 2024-01-05 10:00:00.000: [BUG_REPORT] Could not attach '
          'the logs, opening a mailto link instead\n'
          'Error: Exception: No mail account\n',
        ),
      );

      email.mailtoResult = false;
      expect(await service.reportError(body: 'b'), BugReportOutcome.noMailApp);
    });

    test('falls back to a mailto link when the logs cannot be zipped, and says '
        'the logs are missing', () async {
      archive.error = Exception('No space left on device');

      final BugReportOutcome outcome = await service.reportError(body: 'b');

      expect(outcome, BugReportOutcome.mailtoOpened);
      expect(email.sent, isEmpty);
      expect(
        email.mailtos.single.subject,
        '[One Second Diary - v2.0.0] App Error Report',
      );
      expect(email.mailtos.single.body, 'b\n\n(logs unavailable)');
    });
  });

  group('shareIdea', () {
    test('opens a mailto link to the developer with the Feedback '
        'subject', () async {
      final BugReportOutcome outcome = await service.shareIdea(
        body: 'Hi Kyle!',
      );

      expect(outcome, BugReportOutcome.mailtoOpened);
      expect(email.mailtos, <EmailDraft>[
        const EmailDraft(
          recipient: 'kylekundev@gmail.com',
          subject: '[One Second Diary - v2.0.0] Feedback',
          body: 'Hi Kyle!',
          attachmentPaths: <String>[],
        ),
      ]);
      expect(archive.zips, isEmpty);
    });
  });
}
