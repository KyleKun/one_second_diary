import 'package:one_second_diary/core/media/types/clip_format.dart';

/// The bitrate targets of the hardware encoders (VideoToolbox, MediaCodec),
/// per codec and tier, ×1.5 at 60 fps, ×1.2 for 10-bit HLG.
/// libx264 keeps `-crf 20` and never reads this.
///
/// The HLG factor: 10-bit HEVC is not costlier per pixel, but HDR carries
/// highlights SDR clips at these targets never hold, and Apple's own HLG
/// recordings run about a fifth above their SDR ones at the same size.
abstract final class EncoderPolicy {
  /// The `-b:v` target for [format], in bits per second: the table's
  /// value, then ×1.5 at 60 fps, then ×1.2 for HLG (whole numbers each
  /// step, so 2160p60 HLG is 50 400 kb/s).
  static int bitrateFor(ClipFormat format) {
    final int kbps = switch ((format.tier, format.codec)) {
      (ResolutionTier.p720, VideoCodec.h264) => 5000,
      (ResolutionTier.p720, VideoCodec.hevc) => 3500,
      (ResolutionTier.p1080, VideoCodec.h264) => 12000,
      (ResolutionTier.p1080, VideoCodec.hevc) => 8000,
      (ResolutionTier.p1440, VideoCodec.h264) => 20000,
      (ResolutionTier.p1440, VideoCodec.hevc) => 13000,
      (ResolutionTier.p2160, VideoCodec.h264) => 45000,
      (ResolutionTier.p2160, VideoCodec.hevc) => 28000,
    };
    final int bps = kbps * 1000;
    final int atRate = switch (format.fps) {
      FrameRate.f30 => bps,
      FrameRate.f60 => bps * 3 ~/ 2,
    };
    return switch (format.range) {
      DynamicRange.sdr => atRate,
      DynamicRange.hlg => atRate * 6 ~/ 5,
    };
  }
}
