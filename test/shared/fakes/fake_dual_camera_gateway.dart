import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/platform/camera_gateway.dart';
import 'package:one_second_diary/core/platform/camera_lens.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';
import 'package:one_second_diary/core/platform/dual_camera_gateway.dart';

import 'fake_camera_gateway.dart';

/// A scriptable pair of cameras over a [FakeCameraGateway] (whose files a
/// stop writes). A phone that can't run both by default: set [supported].
/// [openFailure] makes the next [open] fail; [fail] breaks the open pair,
/// as the plugin reports it after opening.
class FakeDualCameraGateway implements DualCameraGateway {
  FakeDualCameraGateway(this._camera);

  final FakeCameraGateway _camera;

  bool supported = false;

  /// When set, the next [open] throws it (then it is cleared).
  CameraFailureException? openFailure;

  final List<FakeDualCameraSession> sessions = <FakeDualCameraSession>[];

  FakeDualCameraSession? get current => sessions.isEmpty ? null : sessions.last;

  void Function()? _onFailure;

  /// The open pair stops working.
  void fail() => _onFailure?.call();

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<DualCameraSession> open({
    required CameraFacing primary,
    required DualCameraLayout layout,
    required void Function() onFailure,
    bool withAudio = true,
  }) async {
    final CameraFailureException? failure = openFailure;
    if (failure != null) {
      openFailure = null;
      throw failure;
    }
    _onFailure = onFailure;
    final FakeDualCameraSession session = FakeDualCameraSession._(
      // The fake single session under it records and closes.
      await _camera.open(_lensOf(primary), withAudio: withAudio)
          as FakeCameraSession,
      layout,
    );
    sessions.add(session);
    return session;
  }

  static CameraLens _lensOf(CameraFacing facing) => facing == CameraFacing.front
      ? FakeCameraGateway.front
      : FakeCameraGateway.back;
}

/// One opened pair of [FakeDualCameraGateway].
class FakeDualCameraSession extends DelegatingCameraSession
    implements DualCameraSession {
  FakeDualCameraSession._(super.session, this._layout) : _lens = session.lens;

  CameraLens _lens;
  DualCameraLayout _layout;

  @override
  CameraLens get lens => _lens;

  @override
  DualCameraLayout get layout => _layout;

  /// The plugin's composite, always 720×1280.
  @override
  AchievedSize? get achieved => (width: 1280, height: 720);

  @override
  Future<void> show({
    required CameraFacing primary,
    required DualCameraLayout layout,
  }) async {
    _lens = FakeDualCameraGateway._lensOf(primary);
    _layout = layout;
  }
}

/// A [CameraSession] that hands every call to [session].
class DelegatingCameraSession implements CameraSession {
  DelegatingCameraSession(this.session);

  final FakeCameraSession session;

  @override
  CameraLens get lens => session.lens;

  @override
  double get aspectRatio => session.aspectRatio;

  @override
  AchievedSize? get achieved => session.achieved;

  @override
  double get minZoom => 1;

  @override
  double get maxZoom => 1;

  @override
  bool get isRecording => session.isRecording;

  @override
  bool get isClosed => session.isClosed;

  @override
  Widget preview() => session.preview();

  @override
  Future<void> setZoom(double level) async {}

  @override
  Future<void> focusAt(Offset point) async {}

  @override
  Future<void> lockFocusAt(Offset point) async {}

  @override
  Future<bool> setTorch({required bool on}) async => !on;

  @override
  Future<void> lockCaptureOrientation(DeviceOrientation orientation) =>
      session.lockCaptureOrientation(orientation);

  @override
  Future<void> startRecording() => session.startRecording();

  @override
  Future<String> stopRecording() => session.stopRecording();

  @override
  Future<void> close() => session.close();
}
