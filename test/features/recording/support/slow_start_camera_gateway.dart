import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/platform/camera_gateway.dart';
import 'package:one_second_diary/core/platform/camera_lens.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';

import '../../../shared/fakes/fake_camera_gateway.dart';

/// A [FakeCameraGateway] whose sessions start recording at once but say so
/// only when the test lets them ([release]), like the plugin, whose
/// `startVideoRecording` answers a few hundred ms late and reports
/// `isRecordingVideo` only then. The sessions in
/// [FakeCameraGateway.sessions] are the ones underneath.
class SlowStartCameraGateway extends FakeCameraGateway {
  SlowStartCameraGateway({required super.recordingsDir});

  // Made by the first start, in the zone the test runs the bloc in (fake
  // time), so its completion reaches the bloc there.
  Completer<void>? _gate;

  /// Lets the starts waiting answer.
  void release() => _gate?.complete();

  @override
  Future<CameraSession> open(
    CameraLens lens, {
    bool withAudio = true,
    CaptureQuality capture = CaptureQuality.legacy,
  }) async => _SlowStartSession(
    this,
    await super.open(lens, withAudio: withAudio, capture: capture)
        as FakeCameraSession,
  );
}

class _SlowStartSession implements CameraSession {
  _SlowStartSession(this._gateway, this._session);

  final SlowStartCameraGateway _gateway;
  final FakeCameraSession _session;
  bool _started = false;

  @override
  CameraLens get lens => _session.lens;

  @override
  double get aspectRatio => _session.aspectRatio;

  @override
  AchievedSize? get achieved => _session.achieved;

  @override
  double get minZoom => _session.minZoom;

  @override
  double get maxZoom => _session.maxZoom;

  @override
  bool get isRecording => _started && _session.isRecording;

  @override
  bool get isClosed => _session.isClosed;

  @override
  Widget preview() => _session.preview();

  @override
  Future<void> setZoom(double level) => _session.setZoom(level);

  @override
  Future<void> focusAt(Offset point) => _session.focusAt(point);

  @override
  Future<void> lockFocusAt(Offset point) => _session.lockFocusAt(point);

  @override
  Future<bool> setTorch({required bool on}) => _session.setTorch(on: on);

  @override
  Future<void> lockCaptureOrientation(DeviceOrientation orientation) =>
      _session.lockCaptureOrientation(orientation);

  @override
  Future<void> startRecording() async {
    await _session.startRecording();
    await (_gateway._gate ??= Completer<void>()).future;
    _started = true;
  }

  @override
  Future<String> stopRecording() => _session.stopRecording();

  @override
  Future<void> close() => _session.close();
}
