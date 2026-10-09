// ignore_for_file: file_names

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/logging/bug_report_service.dart';
import 'package:one_second_diary/features/settings/presentation/dialogs/contact_dialog.dart';

import '../../shared/harness/settle.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';
import '../../support/track_1d/fake_archive_gateway.dart';

void main() {
  testWidgets('a German user reports a problem: the mail app opens to the '
      "developer with this launch's log zipped and the English subject", (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(extra: <String, Object>{'lang': 'de'}),
    );

    await app.settings.openContact();
    expect(find.text(Strings.contactTitle), findsOneWidget);
    await app.settings.contact(ContactDialog.problemKey);

    final EmailDraft mail = app.harness.gateways.email.sent.single;
    expect(mail.recipient, BugReportService.developerEmail);
    expect(mail.subject, '[One Second Diary - v2.0.0] App Error Report');
    expect(mail.body, Strings.errorMailBody);
    expect(mail.attachmentPaths, <String>[app.harness.paths.logsZipPath]);
    final FakeZip zip = app.harness.gateways.archive.zips.single;
    expect(zip.sourceDir, app.harness.paths.logsDir);
    expect(
      zip.entries.values.where(
        (String log) =>
            log.contains('[MIGRATION] Schema step') &&
            log.contains('[BUG_REPORT] Sending logs to the developer'),
      ),
      hasLength(1),
      reason: "this launch's log, flushed before the zip",
    );
    app.settings.expectContactOpen(open: false);
    app.expectNoPluginChannel();
  });

  testWidgets('a user shares an idea: a plain mail with the Feedback subject '
      'and no attachment', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());

    await app.settings.openContact();
    await app.settings.contact(ContactDialog.ideaKey);

    final EmailDraft mail = app.harness.gateways.email.mailtos.single;
    expect(mail.subject, '[One Second Diary - v2.0.0] Feedback');
    expect(mail.attachmentPaths, isEmpty);
    expect(app.harness.gateways.archive.zips, isEmpty);
  });

  testWidgets('with no mail app the report still tries, then the tab says '
      'where to write and copies the address', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      configureGateways: (gateways) {
        gateways.email
          ..sendError = PlatformException(code: 'not_available')
          ..mailtoResult = false;
      },
    );
    final List<String> clipboard = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add(
            (call.arguments as Map<Object?, Object?>)['text']! as String,
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await app.settings.openContact();
    await app.settings.contact(ContactDialog.problemKey);

    expect(app.harness.gateways.email.sent, hasLength(1));
    expect(app.harness.gateways.email.mailtos, hasLength(1));
    expect(find.text(Strings.contactNoEmailAppTitle), findsOneWidget);
    await tester.tap(find.text(Strings.contactCopyAddress));
    await settle(tester);
    expect(clipboard, <String>[BugReportService.developerEmail]);
    expect(find.text(Strings.commonCopied), findsOneWidget);
  });
}
