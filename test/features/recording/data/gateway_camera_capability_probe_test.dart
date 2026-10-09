// The phone check's camera test over the camera gateway: the back wide
// lens asked for 4K at 60 fps, what it achieved read, a short recording
// probed for its frame rate and channels, then deleted; a camera that
// cannot be opened reads as unknown.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/platform/camera_lens.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';
import 'package:one_second_diary/features/recording/data/gateway_camera_capability_probe.dart';

import '../../../shared/fakes/fake_camera_gateway.dart';
import '../../../support/support.dart';

void main() {
  late AppPaths paths;
  late MemoryLogSink log;
  late FakeCameraGateway camera;
  late FakeMediaEngine media;
  late List<Duration> waited;

  const CameraLens ultraWide = CameraLens(
    id: 'ultra',
    facing: CameraFacing.back,
    sensorOrientation: 90,
    kind: CameraLensKind.ultraWide,
  );
  const CameraLens wide = CameraLens(
    id: 'wide',
    facing: CameraFacing.back,
    sensorOrientation: 90,
    kind: CameraLensKind.wide,
  );

  setUp(() async {
    paths = await createTestPaths();
    log = MemoryLogSink();
    camera = FakeCameraGateway(recordingsDir: paths.temporaryDir);
    media = FakeMediaEngine(scratchDir: paths.scratchDir);
    waited = <Duration>[];
  });

  GatewayCameraCapabilityProbe probe() => GatewayCameraCapabilityProbe(
    camera: camera,
    engine: media,
    logger: memoryLogger(log),
    wait: (Duration duration) async => waited.add(duration),
  );

  /// Scripts the probe of the next recording the fake camera writes.
  void recordingProbes({
    required double fps,
    required int? channels,
    int width = 1920,
    int height = 1080,
  }) {
    media.probes['${paths.temporaryDir}/REC_1.mp4'] = ClipProbe(
      durationMs: 500,
      hasAudio: channels != null,
      hasSubtitleStream: false,
      artist: null,
      album: null,
      comment: null,
      locationTag: null,
      title: null,
      width: width,
      height: height,
      codec: 'h264',
      fps: fps,
      channels: channels,
    );
  }

  test('a flagship: the back wide lens (not the ultra wide) opened at 4K '
      '60 fps achieves 4K, records 60 fps stereo; the recording is probed '
      'then deleted and the lens closed', () async {
    camera
      ..lensList = <CameraLens>[ultraWide, wide, FakeCameraGateway.front]
      ..achieved = (width: 3840, height: 2160);
    recordingProbes(fps: 59.94, channels: 2, width: 3840, height: 2160);

    final CameraCapability? found = await probe().probe();

    expect(
      found,
      const CameraCapability(
        maxTier: ResolutionTier.p2160,
        fps60: true,
        channels: 2,
      ),
    );
    expect(camera.sessions.single.lens, wide);
    expect(
      camera.sessions.single.quality,
      const CaptureQuality(tier: ResolutionTier.p2160, fps: FrameRate.f60),
    );
    expect(waited, <Duration>[GatewayCameraCapabilityProbe.recordFor]);
    expect(media.probedPaths, <String>['${paths.temporaryDir}/REC_1.mp4']);
    expect(File('${paths.temporaryDir}/REC_1.mp4').existsSync(), isFalse);
    expect(camera.isOpen, isFalse);
  });

  test('a lens that falls back to 1080p at 30 fps mono reads as such; '
      'a back lens of unknown kind (Android) serves', () async {
    camera.achieved = (width: 1920, height: 1080);
    recordingProbes(fps: 30, channels: null);

    final CameraCapability? found = await probe().probe();

    expect(
      found,
      const CameraCapability(
        maxTier: ResolutionTier.p1080,
        fps60: false,
        channels: 1,
      ),
    );
    expect(camera.sessions.single.lens, FakeCameraGateway.back);
  });

  test('the recording file decides the tier, not the session\'s achieved '
      'size: Android\'s preview reads 1080p while the lens records 4K, '
      'and a 4K preview over a 1080p file is still 1080p', () async {
    camera.achieved = (width: 1920, height: 1080);
    recordingProbes(fps: 30, channels: 1, width: 3840, height: 2160);
    expect((await probe().probe())!.maxTier, ResolutionTier.p2160);

    camera.achieved = (width: 3840, height: 2160);
    recordingProbes(fps: 30, channels: 1);
    expect((await probe().probe())!.maxTier, ResolutionTier.p1080);
  });

  test('without a back lens, or when the lens cannot be opened, the '
      'camera is unknown, logged, and nothing stays open', () async {
    camera.lensList = <CameraLens>[FakeCameraGateway.front];
    expect(await probe().probe(), isNull);
    expect(camera.sessions, isEmpty);

    camera
      ..lensList = <CameraLens>[FakeCameraGateway.back]
      ..openFailure = const CameraFailureException('busy');
    expect(await probe().probe(), isNull);
    expect(camera.isOpen, isFalse);
    expect(
      log.lines.where((String l) => l.startsWith('[WARNING]')),
      hasLength(2),
    );
  });
}
