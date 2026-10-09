// The phone check's cubit over the real PhoneCheck and fakes: running with
// progress → done with the recommendation; Skip selects Standard and lets
// the check finish in the background; back cancels; a failed check selects
// Standard; the Settings page opens on the stored result, stale or not.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/onboarding/data/phone_check.dart';
import 'package:one_second_diary/features/onboarding/domain/phone_check_progress.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/phone_check_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/phone_check_state.dart';
import 'package:one_second_diary/features/profiles/data/device_media_profile_store.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';

import '../../../../shared/fakes/fake_app_info_gateway.dart';
import '../../../../shared/fakes/fake_camera_capability_probe.dart';
import '../../../../shared/fakes/fake_device_media_check_runner.dart';
import '../../../../shared/fakes/fake_free_space_gateway.dart';
import '../../../../support/support.dart';

void main() {
  late MemoryLogSink log;
  late FakeDeviceMediaCheckRunner runner;
  late FakeCameraCapabilityProbe camera;
  late FakeAppInfoGateway appInfo;
  late DeviceMediaProfileStore store;
  late PhoneCheck check;

  final ClipFormat standard = FakeDeviceMediaCheckRunner.format();
  final ClipFormat ultra = FakeDeviceMediaCheckRunner.format(
    tier: ResolutionTier.p2160,
    codec: VideoCodec.hevc,
    fps: FrameRate.f60,
  );
  const ClipFormat ultraStereo = ClipFormat(
    tier: ResolutionTier.p2160,
    orientation: VideoOrientation.portrait,
    codec: VideoCodec.hevc,
    fps: FrameRate.f60,
    channels: AudioChannels.stereo,
    range: DynamicRange.sdr,
  );

  setUp(() async {
    log = MemoryLogSink();
    runner = FakeDeviceMediaCheckRunner(
      encode: <ClipFormat, EncodeResult>{
        standard: const EncodeResult(ok: true, realtimeFactor: 3),
        ultra: const EncodeResult(ok: true, realtimeFactor: 1.5),
      },
    );
    camera = FakeCameraCapabilityProbe();
    appInfo = FakeAppInfoGateway(appVersion: '2.1.0');
    final FakeDeviceInfoGateway deviceInfo = FakeDeviceInfoGateway(sdkInt: 34);
    final PrefsStore prefs = await openLegacyPrefs(legacyPrefs());
    store = DeviceMediaProfileStore(
      prefs: prefs,
      appInfo: appInfo,
      deviceInfo: deviceInfo,
      logger: memoryLogger(log),
    );
    check = PhoneCheck(
      runner: runner,
      camera: camera,
      freeSpace: FakeFreeSpaceGateway(free: 480 * 1000 * 1000 * 1000),
      permissions: PermissionRequester(
        permissions: FakePermissionGateway()
          ..statuses[AppPermission.camera] = AppPermissionStatus.granted
          ..statuses[AppPermission.microphone] = AppPermissionStatus.granted,
        deviceInfo: deviceInfo,
        logger: memoryLogger(log),
      ),
      store: store,
      clock: FakeClock(DateTime(2026, 10, 7, 10)),
      logger: memoryLogger(log),
    );
  });

  PhoneCheckCubit cubit({
    VideoOrientation orientation = VideoOrientation.portrait,
  }) {
    final PhoneCheckCubit cubit = PhoneCheckCubit(
      check: check,
      store: store,
      orientation: orientation,
      isIOS: false,
      logger: memoryLogger(log),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('opens idle; start runs with the progress of each test, then is '
      'done with the profile and the recommendation on the canvas asked, '
      'the pick selected', () async {
    final PhoneCheckCubit subject = cubit();
    expect(subject.state.status, PhoneCheckStatus.idle);
    final List<PhoneCheckState> seen = <PhoneCheckState>[];
    subject.stream.listen(seen.add);

    await subject.start();

    expect(subject.state.status, PhoneCheckStatus.done);
    expect(subject.state.profile, store.read());
    expect(subject.state.stale, isFalse);
    expect(subject.state.recommendation!.pick, ultraStereo);
    expect(subject.state.selected, ultraStereo);
    expect(subject.state.hasResult, isTrue);
    expect(
      seen.map((PhoneCheckState s) => (s.status, s.progress?.test)),
      <(PhoneCheckStatus, PhoneCheckTest?)>[
        (PhoneCheckStatus.running, null),
        (PhoneCheckStatus.running, PhoneCheckTest.encode),
        (PhoneCheckStatus.running, PhoneCheckTest.encode),
        (PhoneCheckStatus.running, PhoneCheckTest.camera),
        (PhoneCheckStatus.running, PhoneCheckTest.storage),
        (PhoneCheckStatus.done, null),
      ],
    );
  });

  test(
    '"Choose another" selects the format picked, on the canvas asked',
    () async {
      final PhoneCheckCubit subject = cubit();
      await subject.start();

      subject.select(standard);

      expect(
        subject.state.selected,
        standard.withOrientation(VideoOrientation.portrait),
      );
      expect(
        subject.state.recommendation!.pick,
        ultraStereo,
        reason: 'the pick stays',
      );
    },
  );

  test('Skip selects Standard at once while the check goes on in the '
      'background and stores its result for the next profile, even once '
      'the cubit is closed', () async {
    runner.hold = true;
    final PhoneCheckCubit subject = cubit();
    final Future<void> running = subject.start();
    await pumpEventQueue();
    expect(subject.state.isRunning, isTrue);

    subject.skip();

    expect(subject.state.status, PhoneCheckStatus.skipped);
    expect(
      subject.state.selected,
      ClipFormatPreset.standard.format(VideoOrientation.portrait),
    );
    expect(subject.state.recommendation!.checked, isFalse);
    await subject.close();
    runner.release();
    await running;
    await pumpEventQueue();

    expect(store.read(), isNotNull);
    expect(runner.runs.single.cancelled, isFalse);
  });

  test('back cancels a running check (closing the cubit too): nothing is '
      'stored', () async {
    runner.hold = true;
    final PhoneCheckCubit subject = cubit();
    final Future<void> running = subject.start();
    await pumpEventQueue();

    await subject.cancel();
    await running;

    expect(subject.state.status, PhoneCheckStatus.idle);
    expect(runner.runs.single.cancelled, isTrue);
    expect(store.read(), isNull);

    final PhoneCheckCubit closed = cubit();
    final Future<void> second = closed.start();
    await pumpEventQueue();
    await closed.close();
    await second;
    expect(runner.runs.last.cancelled, isTrue);
  });

  test('a check that fails selects Standard and says so', () async {
    runner.fail = true;
    final PhoneCheckCubit subject = cubit();

    await subject.start();

    expect(subject.state.status, PhoneCheckStatus.failed);
    expect(subject.state.profile, isNull);
    expect(
      subject.state.selected,
      ClipFormatPreset.standard.format(VideoOrientation.portrait),
    );
    expect(subject.state.hasResult, isTrue);
  });

  test('Settings opens on the stored result: current, it recommends from '
      'it; from another app version it is stale and Standard is '
      'recommended; nothing stored leaves the cubit idle', () async {
    final PhoneCheckCubit idle = cubit();
    await idle.loadStored();
    expect(idle.state.status, PhoneCheckStatus.idle);

    await check.start().result;
    final PhoneCheckCubit current = cubit();
    await current.loadStored();
    expect(current.state.status, PhoneCheckStatus.done);
    expect(current.state.stale, isFalse);
    expect(current.state.recommendation!.pick, ultraStereo);

    appInfo.appVersion = '2.2.0';
    final PhoneCheckCubit stale = cubit();
    await stale.loadStored();
    expect(stale.state.status, PhoneCheckStatus.done);
    expect(stale.state.stale, isTrue);
    expect(stale.state.profile, isNotNull);
    expect(stale.state.recommendation!.checked, isFalse);
    expect(
      stale.state.selected,
      ClipFormatPreset.standard.format(VideoOrientation.portrait),
    );
  });
}
