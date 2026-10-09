import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/features/onboarding/domain/camera_capability_probe.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';

/// A [CameraCapabilityProbe] answering [capability] (null: the camera
/// could not be opened); [probes] counts the calls.
final class FakeCameraCapabilityProbe implements CameraCapabilityProbe {
  FakeCameraCapabilityProbe({this.capability = flagship});

  /// A 4K 60 fps stereo camera.
  static const CameraCapability flagship = CameraCapability(
    maxTier: ResolutionTier.p2160,
    fps60: true,
    channels: 2,
  );

  /// A 1080p 30 fps mono camera.
  static const CameraCapability basic = CameraCapability(
    maxTier: ResolutionTier.p1080,
    fps60: false,
    channels: 1,
  );

  CameraCapability? capability;
  int probes = 0;

  @override
  Future<CameraCapability?> probe() async {
    probes++;
    return capability;
  }
}
