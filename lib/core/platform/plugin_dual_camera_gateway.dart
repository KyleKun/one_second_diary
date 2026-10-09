import 'dart:async';

import 'package:dual_cameras/dual_cameras.dart' as plugin;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/camera_lens.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';
import 'package:one_second_diary/core/platform/dual_camera_gateway.dart';

/// [DualCameraGateway] over the `dual_cameras` plugin (0.1): both cameras
/// composited on the GPU into one 720×1280 picture, which is the preview
/// and the recording.
///
/// The plugin has one native session at a time, and reports a session that
/// stops working through its controller's `errorMessage`.
final class PluginDualCameraGateway implements DualCameraGateway {
  PluginDualCameraGateway({required this._logger});

  final AppLogger _logger;

  static const String _tag = 'DUAL_CAMERA';

  /// The inset picture: this much of the clip's height, this far from its
  /// edges and this round, in px of the 720 wide picture.
  static const double _insetScale = .28;
  static const double _insetMargin = 24;
  static const double _insetRadius = 24;

  @override
  Future<bool> isSupported() async {
    try {
      return await plugin.DualCameraController.isSupported();
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not ask whether two cameras can run at once',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<DualCameraSession> open({
    required CameraFacing primary,
    required DualCameraLayout layout,
    required void Function() onFailure,
    bool withAudio = true,
  }) async {
    final plugin.DualCameraController controller =
        plugin.DualCameraController();
    try {
      await controller.initialize(
        layout: configOf(primary, layout),
        recordAudio: withAudio,
      );
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'failed to initialize both cameras',
        error: error,
        stackTrace: stackTrace,
      );
      try {
        await controller.dispose();
      } on Object catch (error, stackTrace) {
        _logger.warning(
          _tag,
          'Could not release the cameras',
          error: error,
          stackTrace: stackTrace,
        );
      }
      throw CameraFailureException('Could not open both cameras', cause: error);
    }
    return _PluginDualCameraSession(
      controller: controller,
      primary: primary,
      layout: layout,
      onFailure: onFailure,
      logger: _logger,
    );
  }

  /// The plugin's layout for [primary] leading in [layout].
  @visibleForTesting
  static plugin.LayoutConfig configOf(
    CameraFacing primary,
    DualCameraLayout layout,
  ) {
    final plugin.CameraLens lens = primary == CameraFacing.front
        ? plugin.CameraLens.front
        : plugin.CameraLens.back;
    return switch (layout) {
      // Top left: the date is burned top right or bottom left, the place
      // bottom right.
      DualCameraLayout.inset => plugin.DualLayout.pictureInPicture(
        primary: lens,
        insetCorner: plugin.InsetCorner.topLeft,
        insetScale: _insetScale,
        cornerRadius: _insetRadius,
        margin: _insetMargin,
      ),
      DualCameraLayout.split => plugin.DualLayout.splitVertical(primary: lens),
    };
  }
}

final class _PluginDualCameraSession implements DualCameraSession {
  _PluginDualCameraSession({
    required this.controller,
    required CameraFacing primary,
    required this._layout,
    required this.onFailure,
    required this.logger,
  }) : _lens = _lensOf(primary) {
    controller.addListener(_onController);
    _onController();
  }

  final plugin.DualCameraController controller;
  final void Function() onFailure;
  final AppLogger logger;

  CameraLens _lens;
  DualCameraLayout _layout;

  /// The preview's texture, kept apart from the controller so a preview
  /// still mounted after [close] never listens to a disposed controller.
  final ValueNotifier<int?> _texture = ValueNotifier<int?>(null);

  bool _closed = false;
  bool _failed = false;
  Future<String>? _stopping;
  Future<void>? _closing;

  static const String _tag = 'DUAL_CAMERA';

  /// The size of the plugin's composite, in the sensor's orientation.
  static const AchievedSize compositeSize = (width: 1280, height: 720);

  static CameraLens _lensOf(CameraFacing facing) => CameraLens(
    id: 'dual-${facing.name}',
    facing: facing,
    sensorOrientation: 0,
  );

  void _onController() {
    if (_closed) return;
    final plugin.DualCameraValue value = controller.value;
    _texture.value = value.textureId;
    final String? error = value.errorMessage;
    if (error == null || _failed) return;
    _failed = true;
    logger.error(_tag, 'both cameras stopped working: $error');
    onFailure();
  }

  @override
  CameraLens get lens => _lens;

  @override
  DualCameraLayout get layout => _layout;

  /// The picture is 9 wide and 16 high, upright: as a sensor's would be,
  /// turned.
  @override
  double get aspectRatio => 16 / 9;

  /// The composite is always 720×1280 (a documented limitation of the
  /// plugin): a profile above 720p gets it scaled up at the save.
  @override
  AchievedSize? get achieved => compositeSize;

  @override
  double get minZoom => 1;

  @override
  double get maxZoom => 1;

  @override
  bool get isClosed => _closed;

  @override
  bool get isRecording => !_closed && controller.value.isRecording;

  @override
  Widget preview() => _closed
      ? const SizedBox.shrink()
      : ValueListenableBuilder<int?>(
          valueListenable: _texture,
          builder: (BuildContext context, int? texture, _) =>
              texture == null || _closed
              ? const SizedBox.shrink()
              : Texture(textureId: texture),
        );

  @override
  Future<void> show({
    required CameraFacing primary,
    required DualCameraLayout layout,
  }) async {
    if (_closed) return;
    _lens = _lensOf(primary);
    _layout = layout;
    try {
      await controller.setLayout(
        PluginDualCameraGateway.configOf(primary, layout),
      );
    } on Object catch (error, stackTrace) {
      logger.warning(
        _tag,
        'Could not set the layout',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  // One fixed picture: nothing to zoom, focus, light or turn.
  @override
  Future<void> setZoom(double level) async {}

  @override
  Future<void> focusAt(Offset point) async {}

  @override
  Future<void> lockFocusAt(Offset point) async {}

  @override
  Future<bool> setTorch({required bool on}) async => !on;

  @override
  Future<void> lockCaptureOrientation(DeviceOrientation orientation) async {}

  @override
  Future<void> startRecording() async {
    if (_closed) throw const CameraFailureException('The cameras are closed');
    try {
      await controller.startRecording();
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
        const CameraFailureException('The cameras are closed'),
      );
    }
    return _stopping ??= _stop().whenComplete(() => _stopping = null);
  }

  Future<String> _stop() async {
    if (!controller.value.isRecording) {
      throw const CameraFailureException('Nothing is recording');
    }
    try {
      return await controller.stopRecording();
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
    if (controller.value.isRecording) {
      try {
        await stopRecording();
      } on CameraFailureException {
        // Logged by the stop; the cameras are released all the same.
      }
    }
    _closed = true;
    controller.removeListener(_onController);
    _texture.value = null;
    try {
      // Completes once the cameras and the microphone are given back, so
      // the single camera can open right after.
      await controller.dispose();
    } on Object catch (error, stackTrace) {
      logger.warning(
        _tag,
        'Could not release the cameras',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
