import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

/// The pixel size of a profile's canvas, by its short side.
enum ResolutionTier {
  /// 1280×720: old phones, small files.
  p720(shortSide: 720, longSide: 1280),

  /// 1920×1080: the legacy format's tier.
  p1080(shortSide: 1080, longSide: 1920),

  /// 2560×1440 ("2K", QHD). No camera preset on either platform: the camera
  /// records 4K and the save scales down.
  p1440(shortSide: 1440, longSide: 2560),

  /// 3840×2160 (4K).
  p2160(shortSide: 2160, longSide: 3840);

  const ResolutionTier({required this.shortSide, required this.longSide});

  final int shortSide;
  final int longSide;

  /// The tier's token in a [ClipFormat] string: `720`, `1080`, ...
  String get token => '$shortSide';
}

/// The video codec of a clip. The token is also what ffprobe reports as
/// `codec_name`.
enum VideoCodec {
  h264('h264'),

  /// Always written as `hvc1` (Apple players refuse `hev1`).
  hevc('hevc');

  const VideoCodec(this.token);

  final String token;
}

/// The constant frame rate of a clip. 120 is not a format.
enum FrameRate {
  f30(30),
  f60(60);

  const FrameRate(this.value);

  /// Frames per second.
  final int value;

  String get token => '$value';
}

/// The audio channel layout of a clip (AAC-LC 48 kHz 256 kb/s either way).
enum AudioChannels {
  mono(1),
  stereo(2);

  const AudioChannels(this.count);

  final int count;

  /// The token in a [ClipFormat] string and in ffmpeg's `channel_layout`.
  String get token => name;
}

/// The dynamic range of a clip.
enum DynamicRange {
  sdr,

  /// HEVC Main10, 10-bit, BT.2020, HLG transfer.
  /// HEVC only: H.264 carries no Main10, so `ClipFormat.parse` rejects
  /// `h264-…-hlg` and the picker never offers it ([ClipFormat.isValid]).
  hlg;

  String get token => name;
}

/// The format of every clip of a profile: canvas, codec, frame rate, audio
/// layout and dynamic range.
///
/// Write-once per profile, because movies are stream-copy joins of clips
/// that must match. [ClipFormat.legacy] is the original format of every
/// clip; its argv stays byte for byte stable.
///
/// The stored form is [toString]: `1080p30-h264-mono-sdr`,
/// `2160p60-hevc-stereo-hlg`. It carries no orientation: that is stored
/// beside it (`orientation_<key>`, which older builds read) and passed to
/// [parse].
final class ClipFormat extends Equatable {
  const ClipFormat({
    required this.tier,
    required this.orientation,
    required this.codec,
    required this.fps,
    required this.channels,
    required this.range,
  });

  /// 1080p H.264 30 fps mono SDR on [orientation]'s canvas.
  const ClipFormat.legacy(this.orientation)
    : tier = ResolutionTier.p1080,
      codec = VideoCodec.h264,
      fps = FrameRate.f30,
      channels = AudioChannels.mono,
      range = DynamicRange.sdr;

  final ResolutionTier tier;
  final VideoOrientation orientation;
  final VideoCodec codec;
  final FrameRate fps;
  final AudioChannels channels;
  final DynamicRange range;

  /// Whether this is [ClipFormat.legacy] (of either orientation): the
  /// format whose clips carry the `v1.5` artist marker and whose argv
  /// older builds produced.
  bool get isLegacy =>
      tier == ResolutionTier.p1080 &&
      codec == VideoCodec.h264 &&
      fps == FrameRate.f30 &&
      channels == AudioChannels.mono &&
      range == DynamicRange.sdr;

  /// The canvas width: the tier's long side in landscape, its short side
  /// in portrait.
  int get width => switch (orientation) {
    VideoOrientation.landscape => tier.longSide,
    VideoOrientation.portrait => tier.shortSide,
  };

  /// The canvas height: the tier's short side in landscape, its long side
  /// in portrait.
  int get height => switch (orientation) {
    VideoOrientation.landscape => tier.shortSide,
    VideoOrientation.portrait => tier.longSide,
  };

  int get shortSide => tier.shortSide;
  int get longSide => tier.longSide;

  /// Whether the codec can carry the range: HEVC Main10 writes HLG, H.264
  /// has no 10-bit profile the phones' encoders take. [parse] reads an
  /// invalid string as null and the engine refuses to encode one.
  bool get isValid => !(codec == VideoCodec.h264 && range == DynamicRange.hlg);

  /// Whether every clip of this format is 10-bit HLG.
  bool get isHdr => range == DynamicRange.hlg;

  /// Frames per second: 30 or 60.
  int get fpsValue => fps.value;

  /// Audio channels: 1 or 2.
  int get channelCount => channels.count;

  /// This format on [orientation]'s canvas.
  ClipFormat withOrientation(VideoOrientation orientation) => ClipFormat(
    tier: tier,
    orientation: orientation,
    codec: codec,
    fps: fps,
    channels: channels,
    range: range,
  );

  /// The format stored as [string] on [orientation]'s canvas, or null for
  /// anything that is not exactly a canonical string ([toString]) of a
  /// valid format ([isValid]: `h264-…-hlg` is not one): never a guess, so
  /// an unknown value reads as "absent" (legacy).
  static ClipFormat? parse(String? string, VideoOrientation orientation) {
    if (string == null) return null;
    final RegExpMatch? match = _canonical.firstMatch(string);
    if (match == null) return null;
    final ResolutionTier? tier = _byToken(ResolutionTier.values, match[1]!);
    final FrameRate? fps = _byToken(FrameRate.values, match[2]!);
    final VideoCodec? codec = _byToken(VideoCodec.values, match[3]!);
    final AudioChannels? channels = _byToken(AudioChannels.values, match[4]!);
    final DynamicRange? range = _byToken(DynamicRange.values, match[5]!);
    if (tier == null ||
        fps == null ||
        codec == null ||
        channels == null ||
        range == null) {
      return null;
    }
    final ClipFormat format = ClipFormat(
      tier: tier,
      orientation: orientation,
      codec: codec,
      fps: fps,
      channels: channels,
      range: range,
    );
    return format.isValid ? format : null;
  }

  static final RegExp _canonical = RegExp(
    r'^(\d+)p(\d+)-([a-z0-9]+)-([a-z]+)-([a-z]+)$',
  );

  static T? _byToken<T extends Enum>(List<T> values, String token) {
    for (final T value in values) {
      if (_tokenOf(value) == token) return value;
    }
    return null;
  }

  static String _tokenOf(Enum value) => switch (value) {
    final ResolutionTier tier => tier.token,
    final FrameRate fps => fps.token,
    final VideoCodec codec => codec.token,
    final AudioChannels channels => channels.token,
    final DynamicRange range => range.token,
    _ => value.name,
  };

  /// The canonical string, e.g. `1080p30-h264-mono-sdr`: what the profile
  /// preference stores and the logs show. No orientation (see the class
  /// doc).
  @override
  String toString() =>
      '${tier.token}p${fps.token}-${codec.token}-${channels.token}-'
      '${range.token}';

  @override
  List<Object?> get props => <Object?>[
    tier,
    orientation,
    codec,
    fps,
    channels,
    range,
  ];
}

/// The four qualities the picker offers by name;
/// everything else is under Advanced. The phone check may demote a
/// preset's tier or fps on a phone that cannot do it, and says so.
enum ClipFormatPreset {
  /// 1080p30 H.264 mono: plays everywhere.
  standard(
    tier: ResolutionTier.p1080,
    codec: VideoCodec.h264,
    fps: FrameRate.f30,
    channels: AudioChannels.mono,
  ),

  /// 1080p30 HEVC stereo: about 40 % smaller at the same quality.
  smallerFiles(
    tier: ResolutionTier.p1080,
    codec: VideoCodec.hevc,
    fps: FrameRate.f30,
    channels: AudioChannels.stereo,
  ),

  /// 1440p30 HEVC stereo: sharper on a big screen.
  high(
    tier: ResolutionTier.p1440,
    codec: VideoCodec.hevc,
    fps: FrameRate.f30,
    channels: AudioChannels.stereo,
  ),

  /// 2160p60 HEVC stereo: the most a phone can do.
  ultra(
    tier: ResolutionTier.p2160,
    codec: VideoCodec.hevc,
    fps: FrameRate.f60,
    channels: AudioChannels.stereo,
  );

  const ClipFormatPreset({
    required this.tier,
    required this.codec,
    required this.fps,
    required this.channels,
  });

  final ResolutionTier tier;
  final VideoCodec codec;
  final FrameRate fps;
  final AudioChannels channels;

  /// The preset's format on [orientation]'s canvas. Always SDR: HDR is
  /// Advanced only.
  ClipFormat format(VideoOrientation orientation) => ClipFormat(
    tier: tier,
    orientation: orientation,
    codec: codec,
    fps: fps,
    channels: channels,
    range: DynamicRange.sdr,
  );

  /// The preset whose format [format] is (any orientation), or null when
  /// it is an Advanced choice.
  static ClipFormatPreset? of(ClipFormat format) {
    for (final ClipFormatPreset preset in values) {
      if (preset.format(format.orientation) == format) return preset;
    }
    return null;
  }
}
