import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/platform/camera_lens.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';

/// The in-app camera (`camera`): video with sound at the profile's
/// [CaptureQuality], the capture orientation locked to portrait until a
/// recording locks it to the phone's orientation.
///
/// Permissions are asked before (`PermissionRequester`, camera and
/// microphone); the lifecycle (release on pause, reopen on resume), the
/// remembered lens and the recording length live above this boundary.
abstract interface class CameraGateway {
  /// The phone's lenses, in the platform's order. Empty when it has none
  /// or the platform failed (logged): a phone may lack a front or a back
  /// lens, so pick with a fallback, never `firstWhere` alone. A side may
  /// have several (wide, ultra wide, telephoto): iOS lists each, Android
  /// only those the phone opens to apps.
  Future<List<CameraLens>> lenses();

  /// Opens [lens]: initialised, with its zoom range read and the capture
  /// orientation locked to portrait. [withAudio] false records without
  /// sound (the microphone is not allowed). [capture] is the size and
  /// frame rate asked for; a lens that cannot do it falls back silently and
  /// [CameraSession.achieved] says what it
  /// does. Throws a `CameraFailureException` when it can't; nothing stays
  /// open then.
  Future<CameraSession> open(
    CameraLens lens, {
    bool withAudio = true,
    CaptureQuality capture = CaptureQuality.legacy,
  });
}

/// One opened lens. Safe to use from a widget's lifecycle: after [close],
/// or after the camera failed, every call is harmless and nothing touches
/// the released controller again.
abstract interface class CameraSession {
  CameraLens get lens;

  /// Width over height of the preview, in the sensor's orientation.
  double get aspectRatio;

  /// The picture size the lens opened at, in the sensor's orientation:
  /// what the recording is made at, which may be below the
  /// `CaptureQuality` asked for (the lens cannot do it). Null when the
  /// platform does not say.
  AchievedSize? get achieved;

  /// The zoom range of [lens] (1.0 is no zoom).
  double get minZoom;
  double get maxZoom;

  bool get isRecording;

  /// Whether the camera was released ([close]), by the caller or after a
  /// failure.
  bool get isClosed;

  /// The live preview, as the plugin draws it (it rotates the texture by
  /// the capture orientation on Android only). Once closed, an empty box:
  /// never the preview of a released controller.
  Widget preview();

  /// Zooms to [level], clamped to [minZoom]..[maxZoom] (pinch to zoom).
  Future<void> setZoom(double level);

  /// Focuses and exposes at [point], in 0..1 of the preview each way (tap
  /// to focus: `setExposurePoint` + `setFocusPoint`), and goes on adjusting
  /// both by itself: a lock ([lockFocusAt]) is released.
  Future<void> focusAt(Offset point);

  /// Focuses and exposes at [point] once, then keeps both as they are (the
  /// AE/AF lock) whatever moves in front of the lens, through recordings
  /// too, until [focusAt] or another lock. The exposure is held a moment
  /// after the focus, once it has settled on [point]. On Android only the
  /// focus is held; the exposure keeps measuring at [point].
  Future<void> lockFocusAt(Offset point);

  /// Turns the lens's light on or off (the flash, kept lit as a torch for
  /// video). False when the platform refuses: the lens has no light (the
  /// front lens, and on an iPhone often the ultra wide or the telephoto
  /// one, on Android a second back camera) and stays dark.
  Future<bool> setTorch({required bool on});

  /// Locks the orientation the next recording is saved in (the phone's, at
  /// the moment recording starts, unless the orientation lock froze one).
  Future<void> lockCaptureOrientation(DeviceOrientation orientation);

  /// Starts recording video, with sound unless the session was opened
  /// without it. Throws a `CameraFailureException`
  /// when the camera is closed, already recording or refuses.
  Future<void> startRecording();

  /// Stops the recording and returns the path of the file the platform
  /// wrote (a camera temp the app owns). A second call while the first is
  /// stopping returns the same file. Throws a `CameraFailureException` when
  /// nothing records or the platform fails.
  Future<String> stopRecording();

  /// Releases the camera, first stopping (and dropping) a recording that
  /// runs. Safe to call more than once, concurrently, and after a failure;
  /// it never throws.
  Future<void> close();
}
