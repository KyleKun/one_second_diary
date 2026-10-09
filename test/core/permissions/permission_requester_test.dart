import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/permissions/access_outcome.dart';
import 'package:one_second_diary/core/permissions/permission_feature.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';

import '../../support/support.dart';

void main() {
  late FakePermissionGateway gateway;
  late FakeDeviceInfoGateway device;
  late PermissionRequester requester;

  setUp(() {
    gateway = FakePermissionGateway();
    device = FakeDeviceInfoGateway(sdkInt: 34);
    requester = PermissionRequester(
      permissions: gateway,
      deviceInfo: device,
      logger: memoryLogger(MemoryLogSink()),
    );
  });

  test('check is granted when every permission of the feature is, blocked '
      'when any one can only be granted in Settings, denied otherwise, and '
      'never shows a prompt (safe at launch)', () async {
    // (camera, microphone, outcome)
    final List<(AppPermissionStatus, AppPermissionStatus, AccessOutcome)> rows =
        [
          (
            AppPermissionStatus.granted,
            AppPermissionStatus.granted,
            AccessOutcome.granted,
          ),
          (
            AppPermissionStatus.granted,
            AppPermissionStatus.denied,
            AccessOutcome.denied,
          ),
          (
            AppPermissionStatus.denied,
            AppPermissionStatus.permanentlyDenied,
            AccessOutcome.blocked,
          ),
        ];

    for (final (camera, microphone, outcome) in rows) {
      gateway.statuses
        ..[AppPermission.camera] = camera
        ..[AppPermission.microphone] = microphone;

      expect(
        await requester.check(PermissionFeature.recording),
        outcome,
        reason: '$camera, $microphone',
      );
    }
    expect(gateway.requested, isEmpty);
    expect(gateway.requestedTogether, isEmpty);
  });

  test('request asks for the whole group in one system request (photos and '
      'videos on Android 13+), and grants what needs nothing without asking '
      '(the diary folder on iOS)', () async {
    device.sdkInt = 33;

    expect(
      await requester.request(PermissionFeature.mediaLibrary),
      AccessOutcome.granted,
    );
    expect(gateway.requestedTogether, <Set<AppPermission>>[
      <AppPermission>{AppPermission.photos, AppPermission.videos},
    ]);

    device.sdkInt = null;

    expect(
      await requester.request(PermissionFeature.mediaLibrary),
      AccessOutcome.granted,
    );
    expect(gateway.requestedTogether, hasLength(1));
  });

  test('request asks the system again after a denial: the "Allow access" '
      "step of the cubit's rationale loop (v1.7 CameraPermission)", () async {
    gateway.answers[AppPermission.microphone] = AppPermissionStatus.denied;
    final AccessOutcome first = await requester.request(
      PermissionFeature.recording,
    );
    // The user taps "Allow access", then allows in the system prompt.
    gateway.answers[AppPermission.microphone] = AppPermissionStatus.granted;

    final AccessOutcome second = await requester.request(
      PermissionFeature.recording,
    );

    expect(first, AccessOutcome.denied);
    expect(second, AccessOutcome.granted);
  });
}
