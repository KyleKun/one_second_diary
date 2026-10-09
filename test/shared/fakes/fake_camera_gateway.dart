import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/platform/camera_gateway.dart';
import 'package:one_second_diary/core/platform/camera_lens.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';

import '../../support/support.dart';

/// A scriptable phone camera. It has a back and a front lens by default
/// ([lensList]); [openFailure] makes the next [open] fail. Each open is a
/// [FakeCameraSession] in [sessions], opened at the quality asked for and
/// achieving [achieved] (1080p landscape unless the test says otherwise);
/// a stop writes a small file into [recordingsDir] (created when needed)
/// and returns its path, like a camera temp.
class FakeCameraGateway implements CameraGateway {
  FakeCameraGateway({required this.recordingsDir});

  static const CameraLens back = CameraLens(
    id: 'back',
    facing: CameraFacing.back,
    sensorOrientation: 90,
  );
  static const CameraLens front = CameraLens(
    id: 'front',
    facing: CameraFacing.front,
    sensorOrientation: 270,
  );

  final String recordingsDir;

  /// The phone's lenses, in order (a phone with one lens: `[back]`).
  List<CameraLens> lensList = <CameraLens>[back, front];

  /// When set, the next [open] throws it (then it is cleared).
  CameraFailureException? openFailure;

  /// The lenses that refuse their light (an iPhone's ultra wide lens).
  final Set<CameraLens> lensesWithoutTorch = <CameraLens>{};

  final List<FakeCameraSession> sessions = <FakeCameraSession>[];

  FakeCameraSession? get current => sessions.isEmpty ? null : sessions.last;

  /// What every lens opened from now on achieves; null for a platform
  /// that does not say.
  AchievedSize? achieved = (width: 1920, height: 1080);

  /// Whether a lens is open right now.
  bool get isOpen => current != null && !current!.isClosed;

  int _recordings = 0;

  @override
  Future<List<CameraLens>> lenses() async => List<CameraLens>.of(lensList);

  @override
  Future<CameraSession> open(
    CameraLens lens, {
    bool withAudio = true,
    CaptureQuality capture = CaptureQuality.legacy,
  }) async {
    final CameraFailureException? failure = openFailure;
    if (failure != null) {
      openFailure = null;
      throw failure;
    }
    if (!lensList.contains(lens)) {
      throw CameraFailureException('No lens "${lens.id}"');
    }
    final FakeCameraSession session = FakeCameraSession._(
      lens: lens,
      withAudio: withAudio,
      quality: capture,
      achieved: achieved,
      hasTorch: !lensesWithoutTorch.contains(lens),
      nextRecording: () => '$recordingsDir/REC_${++_recordings}.mp4',
    );
    sessions.add(session);
    return session;
  }
}

/// One opened lens of [FakeCameraGateway], behaving like the real session
/// after [close] (harmless calls, an empty preview).
class FakeCameraSession implements CameraSession {
  FakeCameraSession._({
    required this.lens,
    required this.withAudio,
    required this.quality,
    required this.achieved,
    required this.nextRecording,
    required this.hasTorch,
  });

  /// The preview while open.
  static const Key previewKey = Key('fakeCamera.preview');

  @override
  final CameraLens lens;

  /// Whether it records sound (the microphone is allowed).
  final bool withAudio;

  /// The quality the lens was asked for.
  final CaptureQuality quality;

  @override
  final AchievedSize? achieved;

  final String Function() nextRecording;

  @override
  double get aspectRatio => 16 / 9;

  @override
  double get minZoom => 1;

  @override
  double get maxZoom => 8;

  double zoom = 1;

  /// Where the preview was tapped last.
  Offset? focus;

  /// Whether the focus and the exposure are held there.
  bool focusLocked = false;

  /// Whether the light is lit (dark when opened).
  bool torch = false;

  /// Whether the lens has a light: every lens but those in
  /// [FakeCameraGateway.lensesWithoutTorch].
  final bool hasTorch;

  /// The capture orientation locked now (portrait when opened).
  DeviceOrientation capture = DeviceOrientation.portraitUp;

  /// The capture orientation of the last recording.
  DeviceOrientation? recordedIn;

  /// When set, the next start or stop throws it (then it is cleared).
  CameraFailureException? startFailure;
  CameraFailureException? stopFailure;

  /// The files the stops returned.
  final List<String> recordings = <String>[];

  bool _recording = false;
  bool _closed = false;

  @override
  bool get isRecording => _recording;

  @override
  bool get isClosed => _closed;

  @override
  Widget preview() => _closed
      ? const SizedBox.shrink()
      : const ColoredBox(key: previewKey, color: Color(0xFF101010));

  @override
  Future<void> setZoom(double level) async {
    if (!_closed) zoom = level.clamp(minZoom, maxZoom);
  }

  @override
  Future<void> focusAt(Offset point) async {
    if (_closed) return;
    focus = point;
    focusLocked = false;
  }

  @override
  Future<void> lockFocusAt(Offset point) async {
    if (_closed) return;
    focus = point;
    focusLocked = true;
  }

  @override
  Future<bool> setTorch({required bool on}) async {
    if (_closed) return false;
    if (on && !hasTorch) return false;
    torch = on;
    return true;
  }

  @override
  Future<void> lockCaptureOrientation(DeviceOrientation orientation) async {
    if (!_closed) capture = orientation;
  }

  @override
  Future<void> startRecording() async {
    if (_closed) throw const CameraFailureException('The camera is closed');
    if (_recording) throw const CameraFailureException('Already recording');
    final CameraFailureException? failure = startFailure;
    if (failure != null) {
      startFailure = null;
      throw failure;
    }
    _recording = true;
    recordedIn = capture;
  }

  @override
  Future<String> stopRecording() async {
    if (_closed) throw const CameraFailureException('The camera is closed');
    if (!_recording) throw const CameraFailureException('Nothing is recording');
    _recording = false;
    final CameraFailureException? failure = stopFailure;
    if (failure != null) {
      stopFailure = null;
      throw failure;
    }
    final File file = File(nextRecording())
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(fakeVideoBytes);
    recordings.add(file.path);
    return file.path;
  }

  @override
  Future<void> close() async {
    _recording = false;
    _closed = true;
  }
}
