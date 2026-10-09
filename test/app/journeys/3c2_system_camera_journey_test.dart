// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/robots/app_robot.dart';
import '../../shared/robots/shell_robot.dart';
import '../../support/support.dart';

final LocalDay _january5 = LocalDay(2024, 1, 5);
final RecordArgs _record = RecordArgs(
  day: _january5,
  profile: ProfileKey.defaultProfile,
);
const String _recorded = '/data/cache/VID_20240105.mp4';

EditClipArgs _editorOn(String path) => EditClipArgs(
  source: VideoSource(path: path, ownership: ClipOwnership.cameraTemp),
  day: _january5,
  profile: ProfileKey.defaultProfile,
);

void main() {
  testWidgets('below Android 10 the phone\'s camera app records, and the '
      'clip editor opens on its file in the camera\'s place', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      isAndroid: true,
      configureGateways: (FakeGateways gateways) {
        gateways.deviceInfo.sdkInt = 28;
        gateways.picker.cameraAnswers.add(const Picked(_recorded));
      },
    );

    await app.recording.open(_record);

    expect(app.recording.picker.cameraOpened, isTrue);
    expect(app.recording.camera.sessions, isEmpty, reason: 'no in-app lens');
    app.shell
      ..expectOpenedWith(_editorOn(_recorded))
      ..expectNoPageOf(AppRoute.record);
    app.expectNoPluginChannel();
  });

  testWidgets('with "Force native camera", leaving the phone\'s camera app '
      'without a clip closes the camera with nothing', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(extra: <String, Object>{'forceNativeCamera': true}),
      configureGateways: (FakeGateways gateways) =>
          gateways.picker.cameraAnswers.add(const PickCancelled()),
    );

    final RouteResult<SavedClip> result = await app.recording.open(_record);

    expect(result.popped, isTrue);
    expect(result.value, isNull);
    app.shell.expectNoPageOf(AppRoute.record);
    app.recording.expectReleased();
  });

  testWidgets('refused the camera, the page asks for it (the camera only), '
      'and the phone\'s camera app opens once allowed', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      isAndroid: true,
      configureGateways: (FakeGateways gateways) {
        gateways.deviceInfo.sdkInt = 28;
        gateways.permissions.answers[AppPermission.camera] =
            AppPermissionStatus.denied;
      },
    );

    await app.recording.open(_record);
    app.recording.expectAccessPanel(
      title: 'Camera access needed',
      action: 'Allow access',
    );

    app.harness.gateways.permissions.answers[AppPermission.camera] =
        AppPermissionStatus.granted;
    app.recording.picker.cameraAnswers.add(const Picked(_recorded));
    await app.recording.tapPanelAction();

    app.shell.expectOpenedWith(_editorOn(_recorded));
  });

  testWidgets('when the in-app camera can\'t start, "Use phone\'s camera '
      'app" records there', (WidgetTester tester) async {
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

    app.recording.picker.cameraAnswers.add(const Picked(_recorded));
    await app.recording.tapUseSystemCamera();

    app.shell
      ..expectOpenedWith(_editorOn(_recorded))
      ..expectNoPageOf(AppRoute.record);
  });
}
