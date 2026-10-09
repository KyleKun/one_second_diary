import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';

void main() {
  // The recording's bitrate is the save's H.264 target x1.3 (it is re-encoded), the audio
  // 256 kb/s explicitly.
  test('the recording bitrate is the H.264 target of the tier and frame '
      'rate ×1.3; the audio bitrate is 256 kb/s', () {
    // (tier, fps) -> bits per second
    final Map<(ResolutionTier, FrameRate), int> table =
        <(ResolutionTier, FrameRate), int>{
          (ResolutionTier.p720, FrameRate.f30): 6500000,
          (ResolutionTier.p1080, FrameRate.f30): 15600000,
          (ResolutionTier.p1080, FrameRate.f60): 23400000,
          (ResolutionTier.p1440, FrameRate.f30): 26000000,
          (ResolutionTier.p2160, FrameRate.f30): 58500000,
          (ResolutionTier.p2160, FrameRate.f60): 87750000,
        };
    for (final MapEntry<(ResolutionTier, FrameRate), int> row
        in table.entries) {
      expect(
        CaptureQuality(tier: row.key.$1, fps: row.key.$2).videoBitrate,
        row.value,
        reason: '${row.key}',
      );
    }
    expect(CaptureQuality.legacy.fpsValue, 30);
    expect(CaptureQuality.audioBitrate, 256000);
  });

  test('legacy is 1080p at 30 fps, what every recording was; a format '
      'asks for its tier and frame rate', () {
    expect(
      CaptureQuality.legacy,
      const CaptureQuality(tier: ResolutionTier.p1080, fps: FrameRate.f30),
    );
    expect(
      CaptureQuality.of(const ClipFormat.legacy(VideoOrientation.portrait)),
      CaptureQuality.legacy,
    );
    expect(
      CaptureQuality.of(
        ClipFormatPreset.ultra.format(VideoOrientation.landscape),
      ),
      const CaptureQuality(tier: ResolutionTier.p2160, fps: FrameRate.f60),
    );
  });
}
