import 'package:one_second_diary/core/media/types/clip_format.dart';

/// The video encoders the app renders clips with, one per codec and
/// platform.
///
/// libx264 exists only in the GPL flavours of ffmpeg-kit, which cannot ship
/// on the App Store, and serves the legacy format alone (`EncoderCatalog`);
/// VideoToolbox (iOS) and MediaCodec (Android) are the platforms' hardware
/// encoders. Never libx265: minutes per 4K clip on a phone.
enum VideoEncoder {
  libx264('libx264', VideoCodec.h264),
  videoToolbox('h264_videotoolbox', VideoCodec.h264),
  mediaCodec('h264_mediacodec', VideoCodec.h264),
  hevcVideoToolbox('hevc_videotoolbox', VideoCodec.hevc),
  hevcMediaCodec('hevc_mediacodec', VideoCodec.hevc);

  const VideoEncoder(this.ffmpegName, this.codec);

  /// The name `ffmpeg -encoders` lists and `-c:v` takes.
  final String ffmpegName;

  /// The codec it writes.
  final VideoCodec codec;
}
