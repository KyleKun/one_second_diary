import 'dart:io';
import 'dart:math' as math;

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/platform/camera_gateway.dart';
import 'package:one_second_diary/core/platform/camera_lens.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';
import 'package:one_second_diary/features/onboarding/domain/camera_capability_probe.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';

/// The camera test of the phone check over the in-app camera: opens the back
/// wide lens at the largest size and 60 fps, records half a second, probes the
/// recording's size, frame rate and channels through the engine, and deletes
/// it (the session's achieved size is used only when the probe has none: on
/// Android it is the preview's, not the recording's). Never throws: a camera
/// that can't be opened reads as unknown.
///
/// Called only with the camera permission granted.
final class GatewayCameraCapabilityProbe implements CameraCapabilityProbe {
  GatewayCameraCapabilityProbe({
    required this.camera,
    required this.engine,
    required this.logger,
    this.wait = _delay,
  });

  final CameraGateway camera;
  final MediaEngine engine;
  final AppLogger logger;

  /// Waits out the recording (`Future.delayed` in the app; tests skip it).
  final Future<void> Function(Duration duration) wait;

  static const String _tag = 'PHONE_CHECK';

  /// How long the test recording runs.
  static const Duration recordFor = Duration(milliseconds: 500);

  /// What the lens is asked for: the most the app ever asks.
  static const CaptureQuality asked = CaptureQuality(
    tier: ResolutionTier.p2160,
    fps: FrameRate.f60,
  );

  /// A recording of at least this many frames per second counts as 60.
  static const double fps60Threshold = 50;

  static Future<void> _delay(Duration duration) =>
      Future<void>.delayed(duration);

  @override
  Future<CameraCapability?> probe() async {
    CameraSession? session;
    String? recording;
    try {
      final CameraLens? lens = _backWide(await camera.lenses());
      if (lens == null) {
        logger.warning(_tag, 'No back lens to test: the camera is unknown');
        return null;
      }
      session = await camera.open(lens, capture: asked);
      await session.startRecording();
      await wait(recordFor);
      recording = await session.stopRecording();
      await session.close();
      final ClipProbe probe = await engine.probe(recording);
      // The file decides. `achieved` is the plugin's preview size, which
      // CameraX caps near the display size (1080p) whatever the video use
      // case records: on Android it under-reports a 4K lens.
      final AchievedSize? achieved = session.achieved;
      final int? width = probe.width ?? achieved?.width;
      final int? height = probe.height ?? achieved?.height;
      if (width == null || height == null || width <= 0 || height <= 0) {
        logger.warning(_tag, 'The camera test gave no size: unknown');
        return null;
      }
      final CameraCapability capability = CameraCapability(
        maxTier: _tierFor(math.min(width, height)),
        fps60: (probe.fps ?? 0) >= fps60Threshold,
        channels: probe.channels ?? 1,
      );
      logger.info(
        _tag,
        'The camera does ${width}x$height at ${probe.fps} fps, '
        '${capability.channels} channel(s)',
      );
      return capability;
    } on Object catch (error, stackTrace) {
      logger.warning(
        _tag,
        'The camera test did not finish: the camera is unknown',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      await session?.close();
      if (recording != null) await _delete(recording);
    }
  }

  /// The back wide lens: the one marked wide, else one of unknown kind
  /// (Android lists its cameras without a kind), else any back lens.
  static CameraLens? _backWide(List<CameraLens> lenses) {
    final List<CameraLens> back = <CameraLens>[
      for (final CameraLens lens in lenses)
        if (lens.facing == CameraFacing.back) lens,
    ];
    for (final CameraLensKind kind in <CameraLensKind>[
      CameraLensKind.wide,
      CameraLensKind.unknown,
    ]) {
      for (final CameraLens lens in back) {
        if (lens.kind == kind) return lens;
      }
    }
    return back.isEmpty ? null : back.first;
  }

  /// The largest tier whose short side fits in [shortSide]; 720p for
  /// anything smaller.
  static ResolutionTier _tierFor(int shortSide) {
    ResolutionTier best = ResolutionTier.p720;
    for (final ResolutionTier tier in ResolutionTier.values) {
      if (tier.shortSide <= shortSide) best = tier;
    }
    return best;
  }

  Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}
