import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/platform/camera_gateway.dart';
import 'package:one_second_diary/core/platform/camera_lens.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';

/// Makes the plugin's controller for a lens, recording sound when
/// [enableAudio], at [capture] (tests pass a fake).
typedef CameraControllerFactory =
    CameraController Function(
      CameraDescription description, {
      required bool enableAudio,
      required CaptureQuality capture,
    });

/// [CameraGateway] over the `camera` plugin (0.12).
final class PluginCameraGateway implements CameraGateway {
  PluginCameraGateway({
    required this._listCameras,
    required this._createController,
    required this._logger,
  });

  /// The controller for [capture]: the tier's preset ([presetFor]), its frame
  /// rate, the video bitrate (the save's target x1.3) and an explicit audio
  /// bitrate; with sound unless the microphone is not allowed.
  static CameraController controllerFor(
    CameraDescription description, {
    required bool enableAudio,
    required CaptureQuality capture,
  }) => CameraController(
    description,
    presetFor(capture.tier),
    enableAudio: enableAudio,
    fps: capture.fpsValue,
    videoBitrate: capture.videoBitrate,
    audioBitrate: CaptureQuality.audioBitrate,
  );

  /// The plugin's preset for a tier: `high` is 720p, `veryHigh` 1080p and
  /// `ultraHigh` the most the lens does (2160p; 1440p has no preset on
  /// either platform, the save scales the 4K recording down).
  static ResolutionPreset presetFor(ResolutionTier tier) => switch (tier) {
    ResolutionTier.p720 => ResolutionPreset.high,
    ResolutionTier.p1080 => ResolutionPreset.veryHigh,
    ResolutionTier.p1440 || ResolutionTier.p2160 => ResolutionPreset.ultraHigh,
  };

  final Future<List<CameraDescription>> Function() _listCameras;
  final CameraControllerFactory _createController;
  final AppLogger _logger;

  static const String _tag = 'CAMERA';

  @override
  Future<List<CameraLens>> lenses() async =>
      (await _descriptions()).map(_lensOf).toList();

  @override
  Future<CameraSession> open(
    CameraLens lens, {
    bool withAudio = true,
    CaptureQuality capture = CaptureQuality.legacy,
  }) async {
    final CameraDescription? description = (await _descriptions())
        .where((CameraDescription d) => d.name == lens.id)
        .firstOrNull;
    if (description == null) {
      throw CameraFailureException('No lens "${lens.id}" on this phone');
    }
    final CameraController controller = _createController(
      description,
      enableAudio: withAudio,
      capture: capture,
    );
    try {
      await controller.initialize();
      final (double min, double max) = await (
        controller.getMinZoomLevel(),
        controller.getMaxZoomLevel(),
      ).wait;
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      return _PluginCameraSession(
        lens: lens,
        controller: controller,
        minZoom: min,
        maxZoom: max,
        achieved: _achievedOf(controller.value.previewSize),
        logger: _logger,
      );
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'failed to initialize camera',
        error: error,
        stackTrace: stackTrace,
      );
      await _release(controller);
      throw CameraFailureException(
        'Could not open the ${lens.facing.name} lens',
        cause: error is ParallelWaitError ? error.errors : error,
      );
    }
  }

  /// The preview size as whole pixels, in the sensor's orientation; null
  /// when the plugin has none.
  static AchievedSize? _achievedOf(Size? previewSize) =>
      previewSize == null || previewSize.isEmpty
      ? null
      : (width: previewSize.width.round(), height: previewSize.height.round());

  Future<List<CameraDescription>> _descriptions() async {
    try {
      return await _listCameras();
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not list the cameras',
        error: error,
        stackTrace: stackTrace,
      );
      return const <CameraDescription>[];
    }
  }

  Future<void> _release(CameraController controller) async {
    try {
      await controller.dispose();
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not release the camera',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static CameraLens _lensOf(CameraDescription description) => CameraLens(
    id: description.name,
    facing: switch (description.lensDirection) {
      CameraLensDirection.front => CameraFacing.front,
      CameraLensDirection.back => CameraFacing.back,
      CameraLensDirection.external => CameraFacing.external,
    },
    sensorOrientation: description.sensorOrientation,
    kind: switch (description.lensType) {
      CameraLensType.wide => CameraLensKind.wide,
      CameraLensType.ultraWide => CameraLensKind.ultraWide,
      CameraLensType.telephoto => CameraLensKind.telephoto,
      CameraLensType.unknown => CameraLensKind.unknown,
    },
  );
}

final class _PluginCameraSession implements CameraSession {
  _PluginCameraSession({
    required this.lens,
    required this.controller,
    required this.minZoom,
    required this.maxZoom,
    required this.achieved,
    required this.logger,
  });

  @override
  final CameraLens lens;
  final CameraController controller;
  @override
  final double minZoom;
  @override
  final double maxZoom;
  @override
  final AchievedSize? achieved;
  final AppLogger logger;

  bool _closed = false;
  Future<String>? _stopping;
  Future<void>? _closing;

  static const String _tag = 'CAMERA';

  @override
  bool get isClosed => _closed;

  @override
  bool get isRecording => !_closed && controller.value.isRecordingVideo;

  @override
  double get aspectRatio => controller.value.aspectRatio;

  @override
  Widget preview() => _closed
      ? const SizedBox.shrink()
      : _SessionPreview(session: this, controller: controller);

  @override
  Future<void> setZoom(double level) => _quietly(
    'zoom',
    () => controller.setZoomLevel(level.clamp(minZoom, maxZoom)),
  );

  /// Counts the focus calls: one overtaken by a newer one stops where it
  /// is, so a tap during a lock's wait is never locked after all.
  int _focusCalls = 0;
  bool _focusLocked = false;

  /// Whether a lock holds the exposure too: everywhere but Android.
  /// Whether a lock holds the exposure too: everywhere but Android.
  ///
  /// The Android plugin sets exposure through Camera2 interop; once it had, on a
  /// Galaxy Z Flip 6, the session could no longer close and every recording came
  /// out empty until the app restarted. So on Android a lock holds only the focus.
  ///
  /// TODO(android-exposure-lock): try a newer `camera_android_camerax`, locking via
  /// `FocusMeteringAction` with an AE region, or held exposure compensation.
  static bool get _locksExposure =>
      defaultTargetPlatform != TargetPlatform.android;

  /// How long the exposure gets to settle on a new point before it is
  /// held (Android holds it at once, as it is; iOS adjusts once by itself).
  static const Duration exposureSettle = Duration(milliseconds: 400);

  @override
  Future<void> focusAt(Offset point) => _focusSteps(<Future<void> Function()>[
    if (_focusLocked) ...<Future<void> Function()>[
      () async {
        _focusLocked = false;
        if (_locksExposure) {
          await controller.setExposureMode(ExposureMode.auto);
        }
      },
      () => controller.setFocusMode(FocusMode.auto),
    ],
    () => controller.setExposurePoint(point),
    () => controller.setFocusPoint(point),
  ]);

  // The points go first, with the exposure free, so both are measured at
  // [point]; then the focus is held (iOS focuses once more there), and the
  // exposure once it has settled.
  @override
  Future<void> lockFocusAt(Offset point) =>
      _focusSteps(<Future<void> Function()>[
        () async {
          _focusLocked = true;
          if (_locksExposure) {
            await controller.setExposureMode(ExposureMode.auto);
          }
        },
        () => controller.setExposurePoint(point),
        () => controller.setFocusPoint(point),
        () => controller.setFocusMode(FocusMode.locked),
        if (_locksExposure) ...<Future<void> Function()>[
          () => Future<void>.delayed(exposureSettle),
          () => controller.setExposureMode(ExposureMode.locked),
        ],
      ]);

  /// Runs [steps] in order, quietly, until a newer focus call or [close].
  Future<void> _focusSteps(List<Future<void> Function()> steps) {
    final int call = ++_focusCalls;
    return _quietly('focus', () async {
      for (final Future<void> Function() step in steps) {
        if (_closed || call != _focusCalls) return;
        await step();
      }
    });
  }

  @override
  Future<bool> setTorch({required bool on}) async {
    if (_closed) return false;
    // Read before anything is asked: the controller keeps only its first camera
    // error, and on Android the "off" below can already be the one a lens without
    // a flash unit answers with.
    final String? errorBefore = controller.value.errorDescription;
    // Off first, also before lighting: the Android plugin keeps "the torch is on"
    // from the previous camera and would skip lighting this one. iOS refuses "off"
    // on a lens without a flash, which is as good as done.
    try {
      await controller.setFlashMode(FlashMode.off);
    } on Object catch (error, stackTrace) {
      logger.warning(
        _tag,
        'Could not turn the torch off',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!on || _closed) return !on;
    try {
      await controller.setFlashMode(FlashMode.torch);
    } on Object catch (error, stackTrace) {
      // iOS throws for a lens without a torch.
      logger.warning(
        _tag,
        'Could not light the torch',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
    // Android does not throw: a lens without a flash unit reports a camera
    // error instead, which reaches the controller a moment later.
    await Future<void>.delayed(torchVerdict);
    if (_closed) return false;
    final String? error = controller.value.errorDescription;
    if (error == null || error == errorBefore) return true;
    logger.warning(_tag, 'The lens has no torch: $error');
    return false;
  }

  /// How long a refused torch takes to show as a camera error on Android.
  static const Duration torchVerdict = Duration(milliseconds: 60);

  @override
  Future<void> lockCaptureOrientation(DeviceOrientation orientation) =>
      _quietly(
        'capture orientation',
        () => controller.lockCaptureOrientation(orientation),
      );

  @override
  Future<void> startRecording() async {
    if (_closed) throw const CameraFailureException('The camera is closed');
    try {
      await controller.startVideoRecording();
    } on Object catch (error, stackTrace) {
      logger.error(
        _tag,
        'Could not start recording',
        error: error,
        stackTrace: stackTrace,
      );
      throw CameraFailureException('Could not start recording', cause: error);
    }
  }

  @override
  Future<String> stopRecording() {
    if (_closed) {
      return Future<String>.error(
        const CameraFailureException('The camera is closed'),
      );
    }
    return _stopping ??= _stop().whenComplete(() => _stopping = null);
  }

  Future<String> _stop() async {
    if (!controller.value.isRecordingVideo) {
      throw const CameraFailureException('Nothing is recording');
    }
    try {
      return (await controller.stopVideoRecording()).path;
    } on Object catch (error, stackTrace) {
      logger.error(
        _tag,
        'Could not stop recording',
        error: error,
        stackTrace: stackTrace,
      );
      throw CameraFailureException('Could not stop recording', cause: error);
    }
  }

  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    if (controller.value.isRecordingVideo) {
      try {
        await stopRecording();
      } on CameraFailureException {
        // Logged by the stop; the camera is released all the same.
      }
    }
    // A lock goes with the camera: the Android plugin keeps "focus locked"
    // for the camera opened next.
    if (_focusLocked) {
      _focusLocked = false;
      try {
        if (_locksExposure) {
          await controller.setExposureMode(ExposureMode.auto);
        }
        await controller.setFocusMode(FocusMode.auto);
      } on Object catch (error, stackTrace) {
        logger.warning(
          _tag,
          'Could not release the focus lock',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    _closed = true;
    try {
      await controller.dispose();
    } on Object catch (error, stackTrace) {
      logger.warning(
        _tag,
        'Could not release the camera',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Runs [call] unless the camera is closed; a platform failure is logged
  /// and swallowed (a missed zoom, focus or torch is not worth an error
  /// state).
  Future<void> _quietly(String what, Future<void> Function() call) async {
    if (_closed) return;
    try {
      await call();
    } on Object catch (error, stackTrace) {
      logger.warning(
        _tag,
        'Could not set the $what',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// The plugin's `CameraPreview`, with one guard more: every build first
/// checks that the session is open, because camera 0.12 keeps
/// `isInitialized` after `dispose` and `buildPreview` then throws.
class _SessionPreview extends StatelessWidget {
  const _SessionPreview({required this.session, required this.controller});

  final _PluginCameraSession session;
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    if (session.isClosed || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<CameraValue>(
      valueListenable: controller,
      builder: (BuildContext context, CameraValue value, _) {
        if (session.isClosed || !value.isInitialized) {
          return const SizedBox.shrink();
        }
        final DeviceOrientation orientation = _orientationOf(value);
        final bool landscape =
            orientation == DeviceOrientation.landscapeLeft ||
            orientation == DeviceOrientation.landscapeRight;
        final Widget texture = controller.buildPreview();
        return AspectRatio(
          aspectRatio: landscape ? value.aspectRatio : 1 / value.aspectRatio,
          child: kIsWeb || defaultTargetPlatform != TargetPlatform.android
              ? texture
              : RotatedBox(
                  quarterTurns: _quarterTurns[orientation]!,
                  child: texture,
                ),
        );
      },
    );
  }

  static const Map<DeviceOrientation, int> _quarterTurns =
      <DeviceOrientation, int>{
        DeviceOrientation.portraitUp: 0,
        DeviceOrientation.landscapeRight: 1,
        DeviceOrientation.portraitDown: 2,
        DeviceOrientation.landscapeLeft: 3,
      };

  static DeviceOrientation _orientationOf(CameraValue value) =>
      (value.isRecordingVideo ? value.recordingOrientation : null) ??
      value.previewPauseOrientation ??
      value.lockedCaptureOrientation ??
      value.deviceOrientation;
}
