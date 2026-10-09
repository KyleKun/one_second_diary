import 'package:one_second_diary/core/platform/camera_gateway.dart';
import 'package:one_second_diary/core/platform/camera_lens.dart';

/// How the two pictures share the clip.
enum DualCameraLayout {
  /// One camera fills the clip; the other is a small picture in its top
  /// start corner, clear of the date and place stamps.
  inset,

  /// One camera over the other, half the clip each.
  split,
}

/// The front and the back camera recording at once (`dual_cameras`), made
/// into one upright 9:16 clip with sound: one picture leads (full frame, or
/// the top half), the other follows.
///
/// Only some phones can: an iPhone XS or later, and the Android phones that
/// open two cameras at once. Permissions are asked before, as for
/// [CameraGateway], and the single camera must be closed first: the two
/// never hold the phone's cameras together.
abstract interface class DualCameraGateway {
  /// Whether this phone can run its front and back cameras at once. False
  /// when the platform can't say (logged).
  Future<bool> isSupported();

  /// Opens both cameras with [primary] leading, laid out as [layout].
  /// [withAudio] false records without sound (the microphone is not
  /// allowed). Throws a `CameraFailureException` when it can't; nothing
  /// stays open then.
  ///
  /// [onFailure] is called, once, when the cameras stop working after they
  /// opened (the phone refuses the pair after all): the session must be
  /// closed.
  Future<DualCameraSession> open({
    required CameraFacing primary,
    required DualCameraLayout layout,
    required void Function() onFailure,
    bool withAudio = true,
  });
}

/// Both cameras, opened. A [CameraSession] whose [lens] is the leading
/// camera and whose preview is the clip as it is recorded (9:16, upright):
/// - it always records upright, whatever orientation is locked;
/// - it has no zoom (1 to 1), no focus point or lock and no light.
abstract interface class DualCameraSession implements CameraSession {
  DualCameraLayout get layout;

  /// Makes [primary] the leading camera and lays the two out as [layout],
  /// at once, also while recording.
  Future<void> show({
    required CameraFacing primary,
    required DualCameraLayout layout,
  });
}
