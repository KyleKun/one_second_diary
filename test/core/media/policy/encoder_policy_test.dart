import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/encoder_policy.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

ClipFormat _format(ResolutionTier tier, VideoCodec codec, FrameRate fps) =>
    ClipFormat(
      tier: tier,
      orientation: VideoOrientation.landscape,
      codec: codec,
      fps: fps,
      channels: AudioChannels.mono,
      range: DynamicRange.sdr,
    );

void main() {
  // GOLDEN: the bitrate table, in bits per second.
  test('the hardware encoders\' target per tier and codec at 30 fps', () {
    const Map<(ResolutionTier, VideoCodec), int> rows =
        <(ResolutionTier, VideoCodec), int>{
          (ResolutionTier.p720, VideoCodec.h264): 5000000,
          (ResolutionTier.p720, VideoCodec.hevc): 3500000,
          (ResolutionTier.p1080, VideoCodec.h264): 12000000,
          (ResolutionTier.p1080, VideoCodec.hevc): 8000000,
          (ResolutionTier.p1440, VideoCodec.h264): 20000000,
          (ResolutionTier.p1440, VideoCodec.hevc): 13000000,
          (ResolutionTier.p2160, VideoCodec.h264): 45000000,
          (ResolutionTier.p2160, VideoCodec.hevc): 28000000,
        };
    for (final MapEntry<(ResolutionTier, VideoCodec), int> row
        in rows.entries) {
      final (ResolutionTier tier, VideoCodec codec) = row.key;
      expect(
        EncoderPolicy.bitrateFor(_format(tier, codec, FrameRate.f30)),
        row.value,
        reason: '$tier $codec',
      );
    }
  });

  test('60 fps is 1.5× the 30 fps target', () {
    expect(
      EncoderPolicy.bitrateFor(
        _format(ResolutionTier.p2160, VideoCodec.hevc, FrameRate.f60),
      ),
      42000000,
    );
    expect(
      EncoderPolicy.bitrateFor(
        _format(ResolutionTier.p720, VideoCodec.hevc, FrameRate.f60),
      ),
      5250000,
    );
  });

  // `-b:v 12000k`, the target of every hardware-encoded 1080p clip.
  test('the legacy format keeps today\'s 12 Mb/s target', () {
    expect(
      EncoderPolicy.bitrateFor(
        const ClipFormat.legacy(VideoOrientation.portrait),
      ),
      12000000,
    );
  });

  // HLG takes 1.2x the SDR target, after the 60 fps factor, whole numbers at each step.
  test('HLG is 1.2× the SDR target, after the 60 fps factor', () {
    ClipFormat hlg(ResolutionTier tier, FrameRate fps) => ClipFormat(
      tier: tier,
      orientation: VideoOrientation.landscape,
      codec: VideoCodec.hevc,
      fps: fps,
      channels: AudioChannels.stereo,
      range: DynamicRange.hlg,
    );
    expect(
      EncoderPolicy.bitrateFor(hlg(ResolutionTier.p1080, FrameRate.f30)),
      9600000,
    );
    expect(
      EncoderPolicy.bitrateFor(hlg(ResolutionTier.p2160, FrameRate.f30)),
      33600000,
    );
    expect(
      EncoderPolicy.bitrateFor(hlg(ResolutionTier.p2160, FrameRate.f60)),
      50400000,
    );
    expect(
      EncoderPolicy.bitrateFor(hlg(ResolutionTier.p720, FrameRate.f60)),
      6300000,
    );
  });
}
