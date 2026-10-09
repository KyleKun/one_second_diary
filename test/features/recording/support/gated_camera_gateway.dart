import 'dart:async';

import 'package:one_second_diary/core/platform/camera_gateway.dart';
import 'package:one_second_diary/core/platform/camera_lens.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';

import '../../../shared/fakes/fake_camera_gateway.dart';

/// A [FakeCameraGateway] whose lenses open only when the test says so
/// ([release]), like a camera plugin that is slow or never answers.
class GatedCameraGateway extends FakeCameraGateway {
  GatedCameraGateway({required super.recordingsDir});

  bool _released = false;

  // Made by the first open, in the zone the test runs the bloc in (fake
  // time), so its completion reaches the bloc there.
  Completer<void>? _gate;

  /// Lets the opens waiting (and every later one) go through.
  void release() {
    _released = true;
    _gate?.complete();
  }

  /// Holds the next opens again, until the next [release].
  void hold() {
    _released = false;
    _gate = null;
  }

  @override
  Future<CameraSession> open(
    CameraLens lens, {
    bool withAudio = true,
    CaptureQuality capture = CaptureQuality.legacy,
  }) async {
    if (!_released) await (_gate ??= Completer<void>()).future;
    return super.open(lens, withAudio: withAudio, capture: capture);
  }
}
