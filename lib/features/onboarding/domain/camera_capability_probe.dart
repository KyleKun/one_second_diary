import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';

/// The camera test of the phone check : opens
/// the back wide lens at the largest preset and 60 fps, reads the achieved
/// size, records half a second, probes its frame rate and channels, and
/// deletes it.
///
/// Implemented over `CameraGateway`; faked in tests. Called only with the camera permission granted.
abstract interface class CameraCapabilityProbe {
  /// What the camera can do; null when it could not be opened (never
  /// throws).
  Future<CameraCapability?> probe();
}
