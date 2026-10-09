// The phone check over fakes: the media tests, the camera probe (only with
// the permission), the free space; stamped, stored; cancel stores nothing;
// an engine that cannot run gives no profile.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/storage/storage_budget.dart';
import 'package:one_second_diary/features/onboarding/data/phone_check.dart';
import 'package:one_second_diary/features/onboarding/domain/phone_check_progress.dart';
import 'package:one_second_diary/features/profiles/data/device_media_profile_store.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';

import '../../../shared/fakes/fake_app_info_gateway.dart';
import '../../../shared/fakes/fake_camera_capability_probe.dart';
import '../../../shared/fakes/fake_device_media_check_runner.dart';
import '../../../shared/fakes/fake_free_space_gateway.dart';
import '../../../support/support.dart';

void main() {
  late MemoryLogSink log;
  late FakeDeviceMediaCheckRunner runner;
  late FakeCameraCapabilityProbe camera;
  late FakeFreeSpaceGateway freeSpace;
  late FakePermissionGateway permissions;
  late FakeDeviceInfoGateway deviceInfo;
  late DeviceMediaProfileStore store;
  late FakeClock clock;

  final ClipFormat standard = FakeDeviceMediaCheckRunner.format();
  final ClipFormat hevc = FakeDeviceMediaCheckRunner.format(
    codec: VideoCodec.hevc,
  );

  setUp(() async {
    log = MemoryLogSink();
    runner = FakeDeviceMediaCheckRunner(
      encode: <ClipFormat, EncodeResult>{
        standard: const EncodeResult(ok: true, realtimeFactor: 3),
        hevc: const EncodeResult(ok: true, realtimeFactor: 2),
      },
      decode: const <String, double>{'iphone-4k60-h264': 2.5},
    );
    camera = FakeCameraCapabilityProbe();
    freeSpace = FakeFreeSpaceGateway(free: 480 * 1000 * 1000 * 1000);
    permissions = FakePermissionGateway()
      ..statuses[AppPermission.camera] = AppPermissionStatus.granted
      ..statuses[AppPermission.microphone] = AppPermissionStatus.granted;
    deviceInfo = FakeDeviceInfoGateway(sdkInt: 34);
    clock = FakeClock(DateTime(2026, 10, 7, 10, 30));
    final PrefsStore prefs = await openLegacyPrefs(legacyPrefs());
    store = DeviceMediaProfileStore(
      prefs: prefs,
      appInfo: FakeAppInfoGateway(appVersion: '2.1.0'),
      deviceInfo: deviceInfo,
      logger: memoryLogger(log),
    );
  });

  PhoneCheck check() => PhoneCheck(
    runner: runner,
    camera: camera,
    freeSpace: freeSpace,
    permissions: PermissionRequester(
      permissions: permissions,
      deviceInfo: deviceInfo,
      logger: memoryLogger(log),
    ),
    store: store,
    clock: clock,
    logger: memoryLogger(log),
  );

  test('runs the media tests, the camera and the free space, reporting '
      'each as it starts, and stores the profile stamped with the clock, '
      'the app version and the phone', () async {
    final PhoneCheckRun run = check().start();
    final List<PhoneCheckProgress> seen = <PhoneCheckProgress>[];
    final StreamSubscription<PhoneCheckProgress> progress = run.progress.listen(
      seen.add,
    );
    addTearDown(progress.cancel);

    final DeviceMediaProfile? profile = await run.result;

    expect(profile, isNotNull);
    expect(profile!.checkedAt, DateTime(2026, 10, 7, 10, 30));
    expect(profile.appVersion, '2.1.0');
    expect(profile.deviceModel, 'Google Pixel 8');
    expect(
      profile.encodeOf(hevc),
      const EncodeResult(ok: true, realtimeFactor: 2),
    );
    expect(profile.decode, <String, double>{'iphone-4k60-h264': 2.5});
    expect(profile.camera, FakeCameraCapabilityProbe.flagship);
    expect(profile.freeBytes, 480 * 1000 * 1000 * 1000);
    expect(store.read(), profile);
    expect(
      seen.map((PhoneCheckProgress p) => (p.test, p.done, p.total)),
      <(PhoneCheckTest, int, int)>[
        (PhoneCheckTest.encode, 0, 5),
        (PhoneCheckTest.encode, 1, 5),
        (PhoneCheckTest.decode, 2, 5),
        (PhoneCheckTest.camera, 3, 5),
        (PhoneCheckTest.storage, 4, 5),
      ],
    );
    expect(seen.first.format, standard);
    expect(camera.probes, 1);
  });

  test('without the camera permission the camera is never probed and stays '
      'unknown (the recommendation then stays at 1080p); the check never '
      'prompts', () async {
    permissions.statuses[AppPermission.camera] = AppPermissionStatus.denied;

    final DeviceMediaProfile? profile = await check().start().result;

    expect(profile!.camera, isNull);
    expect(camera.probes, 0);
    expect(permissions.requestedTogether, isEmpty);
  });

  test(
    'cancel stops after the test in flight: no profile, nothing stored',
    () async {
      runner.hold = true;
      final PhoneCheckRun run = check().start();
      await pumpEventQueue();

      await run.cancel();

      expect(await run.result, isNull);
      expect(run.isCancelled, isTrue);
      expect(store.read(), isNull);
      expect(camera.probes, 0);
    },
  );

  test('a phone without room for the synthetic encodes gets no check: no '
      'profile, the media tests never start, a warning', () async {
    freeSpace.free = StorageBudget.floorBytes;

    expect(await check().start().result, isNull);
    expect(runner.runs, isEmpty);
    expect(store.read(), isNull);
    expect(log.lines, anyElement(contains('[WARNING]')));
  });

  test('an engine that cannot run gives no profile, logged; nothing is '
      'stored', () async {
    runner.fail = true;

    expect(await check().start().result, isNull);
    expect(store.read(), isNull);
    expect(log.lines, anyElement(contains('[ERROR]')));
  });
}
