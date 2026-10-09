import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/policy/encoder_policy.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

/// The picture size a camera session achieved, in the sensor's
/// orientation (the plugin's preview size after init): what the clip is
/// recorded at, whatever quality was asked for.
typedef AchievedSize = ({int width, int height});

/// What the in-app camera is asked to capture, from the profile's format:
/// the tier picks the plugin's resolution preset (720 -> `high`, 1080 ->
/// `veryHigh`, 1440 and 2160 -> `ultraHigh`), the frame rate 30 or 60. Both
/// plugins fall back silently when a lens cannot do it.
final class CaptureQuality extends Equatable {
  const CaptureQuality({required this.tier, required this.fps});

  /// 1080p at 30 fps.
  static const CaptureQuality legacy = CaptureQuality(
    tier: ResolutionTier.p1080,
    fps: FrameRate.f30,
  );

  /// The quality [format] needs: its tier and frame rate.
  factory CaptureQuality.of(ClipFormat format) =>
      CaptureQuality(tier: format.tier, fps: format.fps);

  final ResolutionTier tier;
  final FrameRate fps;

  /// Frames per second asked of the camera: 30 or 60.
  int get fpsValue => fps.value;

  /// The recording's video bitrate, in bits per second: the H.264 target
  /// of the tier and frame rate (`EncoderPolicy`, the camera plugins
  /// record H.264) times [recordingHeadroom], because the recording is
  /// re-encoded at the save and must not be the weakest link.
  int get videoBitrate =>
      EncoderPolicy.bitrateFor(
        ClipFormat(
          tier: tier,
          // The bitrate table does not depend on the canvas.
          orientation: VideoOrientation.landscape,
          codec: VideoCodec.h264,
          fps: fps,
          channels: AudioChannels.mono,
          range: DynamicRange.sdr,
        ),
      ) *
      recordingHeadroomPercent ~/
      100;

  /// How much more than the save's target the camera records at: ×1.3.
  static const int recordingHeadroomPercent = 130;

  /// The recording's audio bitrate, in bits per second: AAC 256 kb/s, the same
  /// as the saved clip's, asked explicitly so neither plugin picks a lower default.
  static const int audioBitrate = 256000;

  @override
  List<Object?> get props => <Object?>[tier, fps];
}
