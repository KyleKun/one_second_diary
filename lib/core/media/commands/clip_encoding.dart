import 'package:one_second_diary/core/media/policy/encoder_catalog.dart';
import 'package:one_second_diary/core/media/policy/transition_policy.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';

/// The encode settings of a `ClipFormat`: a constant frame
/// rate, one AAC 48 kHz 256 kb/s audio stream in the format's layout, the
/// encoder's arguments and the output pixel format, because movies are
/// stream-copy joins of clips that must match. For `ClipFormat.legacy`
/// every list is what earlier versions wrote, byte for byte (but for
/// libx264's `-preset medium`, `EncoderCatalog.argumentsFor`).
///
/// An HLG format writes 10-bit HEVC Main10 with the
/// BT.2020/HLG colour tags ([outputPixelFormat], [hlgPixelFormat]).
abstract final class ClipEncoding {
  /// The pixel format handed to the hardware encoders for HLG: `p010le`
  /// on both platforms. VideoToolbox takes `p010le` for Main10, and
  /// `COLOR_FormatYUVP010` is the one 10-bit YUV input MediaCodec defines
  /// (API 33), the format ffmpeg's `hevc_mediacodec` wrapper maps
  /// `AV_PIX_FMT_P010` to; planar `yuv420p10le` has no MediaCodec colour
  /// format at all. A phone whose wrapper refuses it fails the phone
  /// check's HLG encode test (`DeviceMediaCheck`), which probes the output
  /// for 10 bits and the HLG transfer, so the format is never offered
  /// there.
  static const String hlgPixelFormat = 'p010le';

  /// `-r <fps>`, the audio contract ([audioSettings]; 256 kb/s is high for
  /// mono but is the contract), the encoder, and the output pixel format
  /// ([outputPixelFormat]).
  static List<String> encodeSettings(ClipFormat format, VideoEncoder encoder) =>
      <String>[
        '-r',
        '${format.fpsValue}',
        ...audioSettings(format.channels),
        ...EncoderCatalog.argumentsFor(encoder, format),
        ...outputPixelFormat(format),
      ];

  /// The video half of [encodeSettings] alone (`-r <fps>`, the encoder,
  /// the pixel format), for a render without audio: the transition
  /// segments of a movie, which must match the clips they sit between.
  static List<String> videoEncodeSettings(
    ClipFormat format,
    VideoEncoder encoder,
  ) => <String>[
    '-r',
    '${format.fpsValue}',
    ...EncoderCatalog.argumentsFor(encoder, format),
    ...outputPixelFormat(format),
  ];

  /// `-pix_fmt yuv420p` (player compatibility; an HDR source is tone-mapped
  /// before it by `RangeFilter`, so this never flattens 10-bit colour on
  /// its own) and, for HEVC, `-tag:v hvc1` (Apple players refuse `hev1`).
  ///
  /// An HLG format writes `-pix_fmt p010le` ([hlgPixelFormat]) with the
  /// BT.2100 colour tags, `-color_primaries bt2020 -color_trc arib-std-b67
  /// -colorspace bt2020nc`, so the file and its `colr` atom say HLG, then the `hvc1` tag.
  static List<String> outputPixelFormat(ClipFormat format) =>
      switch (format.range) {
        DynamicRange.sdr => <String>[
          '-pix_fmt',
          'yuv420p',
          if (format.codec == VideoCodec.hevc) ...<String>['-tag:v', 'hvc1'],
        ],
        DynamicRange.hlg => <String>[
          '-pix_fmt',
          hlgPixelFormat,
          '-color_primaries',
          'bt2020',
          '-color_trc',
          'arib-std-b67',
          '-colorspace',
          'bt2020nc',
          '-tag:v',
          'hvc1',
        ],
      };

  /// `-force_key_frames <times>` for a clip [durationMs] long at [fps]: a
  /// keyframe `TransitionPolicy.keyframeMarginMs` from each end, so a
  /// movie with transitions can cut the clip there without re-encoding it. Nothing for a clip too short to hold both.
  static List<String> forcedKeyframes(
    int durationMs, {
    required FrameRate fps,
  }) => switch (TransitionPolicy.forcedKeyframeTimes(durationMs, fps: fps)) {
    final String times => <String>['-force_key_frames', times],
    null => const <String>[],
  };

  /// The audio contract alone (`-ac <1|2> -ar 48000 -c:a aac -b:a 256k`),
  /// for a remux that encodes only a new audio track.
  static List<String> audioSettings(AudioChannels channels) => <String>[
    '-ac',
    '${channels.count}',
    '-ar',
    '48000',
    '-c:a',
    'aac',
    '-b:a',
    '256k',
  ];

  /// An infinite silent 48 kHz source in [channels]'s layout, for clips
  /// whose source has no audio: photos and silent gallery videos. Bounded
  /// by `-shortest` or an output `-t` where it is used.
  static List<String> silentAudioInput(AudioChannels channels) => <String>[
    '-f',
    'lavfi',
    '-i',
    silentSource(channels),
  ];

  /// [silentAudioInput] cut to [durationMs] at the input (`-t` before its
  /// `-i`), for a command that cannot use `-shortest`: one that also maps a
  /// subtitle stream, whose end (1 ms for the placeholder cue) would end the
  /// output there.
  static List<String> silentAudioInputOf(
    AudioChannels channels, {
    required int durationMs,
  }) => <String>[
    '-f',
    'lavfi',
    '-t',
    '${durationMs}ms',
    '-i',
    silentSource(channels),
  ];

  /// The lavfi source of silence in [channels]'s layout.
  static String silentSource(AudioChannels channels) =>
      'anullsrc=channel_layout=${channels.token}:sample_rate=48000';
}
