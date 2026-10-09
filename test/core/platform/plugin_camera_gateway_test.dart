import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/platform/camera_gateway.dart';
import 'package:one_second_diary/core/platform/camera_lens.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';
import 'package:one_second_diary/core/platform/plugin_camera_gateway.dart';

import '../../support/support.dart';

const CameraDescription _back = CameraDescription(
  name: '0',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);
const CameraDescription _front = CameraDescription(
  name: '1',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 270,
);

const Key _texture = Key('texture');

/// The plugin's controller, as far as the gateway uses it. A disposed one
/// throws like camera 0.12 does.
class _Controller extends ValueNotifier<CameraValue>
    implements CameraController {
  _Controller(this.description, {this.initError})
    : super(CameraValue.uninitialized(description));

  @override
  final CameraDescription description;
  final Object? initError;

  bool released = false;
  DeviceOrientation? capture;
  double? zoom;
  Offset? focus;
  Offset? exposure;
  FlashMode? flash;
  FocusMode focusMode = FocusMode.auto;
  ExposureMode exposureMode = ExposureMode.auto;
  Object? startError;
  Completer<XFile>? stopping;

  void _live(String call) {
    if (released) {
      throw CameraException('Disposed CameraController', '$call()');
    }
  }

  @override
  Future<void> initialize() async {
    _live('initialize');
    if (initError != null) throw initError!;
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(1920, 1080),
    );
  }

  @override
  Future<double> getMinZoomLevel() async => 1;

  @override
  Future<double> getMaxZoomLevel() async => 8;

  @override
  Future<void> lockCaptureOrientation([DeviceOrientation? orientation]) async {
    _live('lockCaptureOrientation');
    capture = orientation;
  }

  @override
  Future<void> setZoomLevel(double zoom) async {
    _live('setZoomLevel');
    this.zoom = zoom;
  }

  @override
  Future<void> setFocusPoint(Offset? point) async => focus = point;

  @override
  Future<void> setExposurePoint(Offset? point) async => exposure = point;

  @override
  Future<void> setFocusMode(FocusMode mode) async => focusMode = mode;

  @override
  Future<void> setExposureMode(ExposureMode mode) async => exposureMode = mode;

  @override
  Future<void> setFlashMode(FlashMode mode) async {
    _live('setFlashMode');
    flash = mode;
  }

  @override
  Future<void> startVideoRecording({
    onLatestImageAvailable? onAvailable,
    bool enablePersistentRecording = true,
  }) async {
    _live('startVideoRecording');
    if (startError != null) throw startError!;
    value = value.copyWith(isRecordingVideo: true);
  }

  @override
  Future<XFile> stopVideoRecording() async {
    _live('stopVideoRecording');
    if (!value.isRecordingVideo) {
      throw CameraException('No video is recording', 'stop');
    }
    final XFile file =
        await (stopping?.future ??
            Future<XFile>.value(XFile('/cache/REC_1.mp4')));
    value = value.copyWith(isRecordingVideo: false);
    return file;
  }

  @override
  Widget buildPreview() {
    _live('buildPreview');
    return const SizedBox(key: _texture);
  }

  @override
  Future<void> dispose() async {
    if (released) return;
    released = true;
    super.dispose();
  }

  // As camera 0.12 does: a preview unmounted after the release unsubscribes
  // quietly.
  @override
  void removeListener(VoidCallback listener) {
    if (!released) super.removeListener(listener);
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late MemoryLogSink log;
  late List<_Controller> controllers;
  late List<bool> withAudio;
  late List<CaptureQuality> captures;
  late List<CameraDescription> cameras;
  Object? initError;

  setUp(() {
    log = MemoryLogSink();
    controllers = <_Controller>[];
    withAudio = <bool>[];
    captures = <CaptureQuality>[];
    cameras = <CameraDescription>[_back, _front];
    initError = null;
  });

  PluginCameraGateway gateway({Future<List<CameraDescription>>? list}) =>
      PluginCameraGateway(
        listCameras: () =>
            list ?? Future<List<CameraDescription>>.value(cameras),
        createController:
            (
              CameraDescription description, {
              required bool enableAudio,
              required CaptureQuality capture,
            }) {
              withAudio.add(enableAudio);
              captures.add(capture);
              final _Controller controller = _Controller(
                description,
                initError: initError,
              );
              controllers.add(controller);
              return controller;
            },
        logger: memoryLogger(log),
      );

  const CameraLens back = CameraLens(
    id: '0',
    facing: CameraFacing.back,
    sensorOrientation: 90,
  );

  test('lists every lens with the way it faces, just the back one on a '
      'one-lens phone, and none (logged) on a platform failure', () async {
    const CameraLens front = CameraLens(
      id: '1',
      facing: CameraFacing.front,
      sensorOrientation: 270,
    );
    expect(await gateway().lenses(), <CameraLens>[back, front]);

    cameras = <CameraDescription>[_back];
    expect(await gateway().lenses(), <CameraLens>[back]);

    final List<CameraLens> none = await gateway(
      list: Future<List<CameraDescription>>.error(
        CameraException('CameraAccess', 'no service'),
      ),
    ).lenses();
    expect(none, isEmpty);
    expect(log.lines.single, contains('[CAMERA]'));
  });

  test(
    'opens the lens with its zoom range, with sound as v1.7 or without, '
    'at the legacy quality unless asked otherwise, and locks the capture '
    'to portrait, as v1.7 did; the session says what the lens achieved',
    () async {
      final CameraSession session = await gateway().open(back);
      await gateway().open(back, withAudio: false);
      const CaptureQuality ultra = CaptureQuality(
        tier: ResolutionTier.p2160,
        fps: FrameRate.f60,
      );
      await gateway().open(back, capture: ultra);

      expect(session.lens, back);
      expect(session.minZoom, 1);
      expect(session.maxZoom, 8);
      expect(session.aspectRatio, 1920 / 1080);
      expect(session.achieved, (width: 1920, height: 1080));
      expect(session.isClosed, isFalse);
      expect(controllers.first.capture, DeviceOrientation.portraitUp);
      expect(withAudio, <bool>[true, false, true]);
      expect(captures, <CaptureQuality>[
        CaptureQuality.legacy,
        CaptureQuality.legacy,
        ultra,
      ]);
    },
  );

  // The tier picks the plugin's preset, the frame rate goes through, the recording's
  // bitrate is the save's target x1.3, the audio bitrate is explicit. The legacy quality is
  // 1080p at 30 fps.
  test('the controller for a quality: preset per tier, fps, video bitrate '
      'from the encoder table ×1.3, audio 256 kb/s', () {
    // (tier, fps) -> (preset, fps, videoBitrate)
    final Map<(ResolutionTier, FrameRate), (ResolutionPreset, int, int)> table =
        <(ResolutionTier, FrameRate), (ResolutionPreset, int, int)>{
          (ResolutionTier.p720, FrameRate.f30): (
            ResolutionPreset.high,
            30,
            6500000,
          ),
          (ResolutionTier.p1080, FrameRate.f30): (
            ResolutionPreset.veryHigh,
            30,
            15600000,
          ),
          (ResolutionTier.p1440, FrameRate.f30): (
            ResolutionPreset.ultraHigh,
            30,
            26000000,
          ),
          (ResolutionTier.p2160, FrameRate.f60): (
            ResolutionPreset.ultraHigh,
            60,
            87750000,
          ),
        };
    for (final MapEntry<
          (ResolutionTier, FrameRate),
          (ResolutionPreset, int, int)
        >
        row
        in table.entries) {
      final CameraController controller = PluginCameraGateway.controllerFor(
        _back,
        enableAudio: true,
        capture: CaptureQuality(tier: row.key.$1, fps: row.key.$2),
      );
      expect(controller.resolutionPreset, row.value.$1, reason: '${row.key}');
      expect(controller.mediaSettings.fps, row.value.$2, reason: '${row.key}');
      expect(
        controller.mediaSettings.videoBitrate,
        row.value.$3,
        reason: '${row.key}',
      );
      expect(controller.mediaSettings.audioBitrate, 256000);
      expect(controller.enableAudio, isTrue);
    }
    expect(
      PluginCameraGateway.controllerFor(
        _back,
        enableAudio: false,
        capture: CaptureQuality.legacy,
      ).enableAudio,
      isFalse,
    );
  });

  test("every platform failure is the app's own CameraFailureException, and "
      'a lens that fails to open is released', () async {
    // A lens the phone does not list.
    await expectLater(
      gateway().open(
        const CameraLens(
          id: '9',
          facing: CameraFacing.external,
          sensorOrientation: 0,
        ),
      ),
      throwsA(isA<CameraFailureException>()),
    );
    expect(controllers, isEmpty);

    // Stopping with nothing recording, then a refusal to record.
    final CameraSession session = await gateway().open(back);
    await expectLater(
      session.stopRecording(),
      throwsA(isA<CameraFailureException>()),
    );
    controllers.single.startError = CameraException('IOError', 'disk full');
    await expectLater(
      session.startRecording(),
      throwsA(isA<CameraFailureException>()),
    );
    expect(session.isRecording, isFalse);

    initError = CameraException('CameraAccessDenied', 'in use');
    await expectLater(
      gateway().open(back),
      throwsA(isA<CameraFailureException>()),
    );
    expect(controllers.last.released, isTrue);
  });

  test('a session clamps the zoom to the lens range, focuses and exposes '
      'where the preview was tapped, lights the flash as a torch, and '
      'records in the orientation locked before it starts', () async {
    final CameraSession session = await gateway().open(back);

    await session.setZoom(20);
    expect(controllers.single.zoom, 8);
    await session.setZoom(.2);
    expect(controllers.single.zoom, 1);

    await session.focusAt(const Offset(.25, .75));
    expect(controllers.single.focus, const Offset(.25, .75));
    expect(controllers.single.exposure, const Offset(.25, .75));

    // A long press holds the focus there; a tap meanwhile, or after, lets
    // it go again.
    final Future<void> locking = session.lockFocusAt(const Offset(.5, .5));
    await session.focusAt(const Offset(.1, .2));
    await locking;
    expect(controllers.single.focus, const Offset(.1, .2));
    expect(controllers.single.exposureMode, ExposureMode.auto);
    await session.lockFocusAt(const Offset(.6, .4));
    expect(controllers.single.focus, const Offset(.6, .4));
    expect(controllers.single.exposure, const Offset(.6, .4));
    expect(controllers.single.focusMode, FocusMode.locked);
    // Tests run as Android, where the exposure mode is never touched: once
    // it was, recordings came out empty.
    expect(controllers.single.exposureMode, ExposureMode.auto);
    await session.focusAt(const Offset(.25, .75));
    expect(controllers.single.focusMode, FocusMode.auto);
    expect(controllers.single.exposureMode, ExposureMode.auto);

    await session.setTorch(on: true);
    expect(controllers.single.flash, FlashMode.torch);
    await session.setTorch(on: false);
    expect(controllers.single.flash, FlashMode.off);

    await session.lockCaptureOrientation(DeviceOrientation.landscapeLeft);
    await session.startRecording();
    expect(session.isRecording, isTrue);
    expect(await session.stopRecording(), '/cache/REC_1.mp4');
    expect(session.isRecording, isFalse);
    expect(controllers.single.capture, DeviceOrientation.landscapeLeft);
  });

  test('a second stop while the first runs returns the same file', () async {
    final CameraSession session = await gateway().open(back);
    await session.startRecording();
    controllers.single.stopping = Completer<XFile>();

    final Future<String> first = session.stopRecording();
    final Future<String> second = session.stopRecording();
    controllers.single.stopping!.complete(XFile('/cache/REC_2.mp4'));

    expect(await first, '/cache/REC_2.mp4');
    expect(await second, '/cache/REC_2.mp4');
  });

  test('closing releases the camera, stopping a recording first, even one '
      'that cannot be stopped; later calls are harmless', () async {
    final CameraSession idle = await gateway().open(back);
    await idle.close();
    await idle.close();
    expect(controllers.single.released, isTrue);
    expect(idle.isClosed, isTrue);
    await idle.setZoom(2);
    await idle.focusAt(Offset.zero);
    await idle.setTorch(on: true);
    await idle.lockCaptureOrientation(DeviceOrientation.portraitUp);
    await expectLater(
      idle.startRecording(),
      throwsA(isA<CameraFailureException>()),
    );
    await expectLater(
      idle.stopRecording(),
      throwsA(isA<CameraFailureException>()),
    );

    final CameraSession recording = await gateway().open(back);
    await recording.startRecording();
    await recording.close();
    expect(controllers.last.value.isRecordingVideo, isFalse);
    expect(controllers.last.released, isTrue);
    expect(recording.isRecording, isFalse);

    final CameraSession stuck = await gateway().open(back);
    await stuck.startRecording();
    controllers.last.stopping = Completer<XFile>()
      ..completeError(CameraException('IOError', 'gone'));
    await stuck.close();
    expect(controllers.last.released, isTrue);
  });

  testWidgets('the preview never draws a released controller', (
    WidgetTester tester,
  ) async {
    final CameraSession session = (await tester.runAsync(
      () => gateway().open(back),
    ))!;
    final Widget preview = session.preview();
    await tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: preview),
    );
    expect(find.byKey(_texture), findsOneWidget);

    await tester.runAsync(session.close);
    // The preview on screen redraws (a sensor event, an inherited change)
    // before the page swaps it; camera 0.12 keeps `isInitialized` after
    // dispose.
    tester.element(find.byWidget(preview)).markNeedsBuild();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(_texture), findsNothing);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: session.preview(),
      ),
    );
    expect(find.byKey(_texture), findsNothing);
  });
}
