// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/logging/bug_report_service.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

final RecordArgs _record = RecordArgs(
  day: LocalDay(2024, 1, 5),
  profile: ProfileKey.defaultProfile,
);

void main() {
  testWidgets('refused, the camera explains why it needs the camera and the '
      'microphone, and asks again', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      configureGateways: (FakeGateways gateways) =>
          gateways.permissions.answers[AppPermission.camera] =
              AppPermissionStatus.denied,
    );

    await app.recording.open(_record);
    app.recording.expectAccessPanel(
      title: 'Camera and microphone access',
      action: 'Allow access',
    );
    app.recording.expectReleased();

    app.harness.gateways.permissions.answers[AppPermission.camera] =
        AppPermissionStatus.granted;
    await app.recording.tapPanelAction();

    app.recording
      ..expectNoPanel()
      ..expectLive();
    app.expectNoPluginChannel();
  });

  testWidgets('refused for good, it opens the settings; allowed there, the '
      'camera opens when the app is back', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      configureGateways: (FakeGateways gateways) =>
          gateways.permissions.statuses[AppPermission.camera] =
              AppPermissionStatus.permanentlyDenied,
    );

    await app.recording.open(_record);
    app.recording.expectAccessPanel(
      title: 'Camera and microphone access',
      action: 'Open settings',
    );
    await app.recording.tapPanelAction();
    expect(app.harness.gateways.permissions.settingsOpened, isTrue);

    app.harness.gateways.permissions.statuses[AppPermission.camera] =
        AppPermissionStatus.granted;
    await app.recording.comeBack();

    app.recording
      ..expectNoPanel()
      ..expectLive();
  });

  testWidgets('a camera that can\'t start says so, and Try again opens it', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      configureGateways: (FakeGateways gateways) =>
          gateways.camera.openFailure = const CameraFailureException('In use'),
    );

    await app.recording.open(_record);
    app.recording.expectErrorPanel(
      title: "The camera couldn't start",
      action: 'Try again',
    );

    await app.recording.tapPanelAction();

    app.recording
      ..expectNoPanel()
      ..expectLive();
  });

  testWidgets('a camera that can\'t start offers Report error: the mail app '
      'opens with the logs', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      configureGateways: (FakeGateways gateways) =>
          gateways.camera.openFailure = const CameraFailureException('In use'),
    );
    await app.recording.open(_record);

    await app.recording.tapReportError();

    final EmailDraft report = app.harness.gateways.email.sent.single;
    expect(report.subject, endsWith('App Error Report'));
    expect(report.body, Strings.errorMailBody);
    expect(report.attachmentPaths, <String>[app.harness.paths.logsZipPath]);
    app.recording.expectErrorPanel(
      title: "The camera couldn't start",
      action: 'Try again',
    );
    app.expectNoPluginChannel();
  });

  testWidgets('a clip the camera couldn\'t record offers Report error; with '
      'no mail app on the phone, it says so, with Copy address as everywhere '
      'else', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      configureGateways: (FakeGateways gateways) => gateways.email
        ..sendError = StateError('No composer')
        ..mailtoResult = false,
    );
    await app.recording.open(_record);
    app.recording.camera.current!.startFailure = const CameraFailureException(
      'No space left',
    );
    await app.recording.pressShutter();
    app.recording.expectNotice(
      title: "Couldn't record that clip",
      body: 'Check free space on your phone and try again.',
    );

    await app.recording.tapNoticeAction(Strings.reportError);

    app.recording.expectNotice(
      title: Strings.contactNoEmailAppTitle,
      body: Strings.contactNoEmailAppBody(
        address: BugReportService.developerEmail,
      ),
      action: Strings.contactCopyAddress,
    );
    app.recording.expectLive();
  });

  testWidgets('back from the panel closes the camera', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      configureGateways: (FakeGateways gateways) =>
          gateways.permissions.answers[AppPermission.camera] =
              AppPermissionStatus.denied,
    );

    await app.recording.open(_record);
    expect(await app.shell.pressBack(), isTrue);

    app.shell.expectNoPageOf(_record.route);
  });
}
