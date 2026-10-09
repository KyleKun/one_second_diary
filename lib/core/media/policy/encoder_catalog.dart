import 'dart:convert';

import 'package:one_second_diary/core/media/policy/encoder_policy.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

/// Which encoder renders which format, from one probe of the ffmpeg
/// build's encoder list, and the arguments that go with it.
///
/// The list is probed (`-hide_banner -encoders`) rather than fixed per
/// platform so either ffmpeg-kit flavour works. It only says a wrapper was
/// compiled in: `hevc_mediacodec` can still fail on a given phone, which is
/// what the phone check (`DeviceMediaCheck`) finds out.
final class EncoderCatalog {
  const EncoderCatalog._({required this._available, required this._isIOS});

  /// The catalogue of the build whose `ffmpeg -hide_banner -encoders`
  /// printed [encodersOutput] (`''` for a failed probe: every format then
  /// takes its platform default).
  factory EncoderCatalog.of(String encodersOutput, {required bool isIOS}) =>
      EncoderCatalog._(available: parseEncoders(encodersOutput), isIOS: isIOS);

  final Set<String> _available;
  final bool _isIOS;

  /// The encoder for [format]: the first of its preference order that the
  /// build lists, else the first of that order (the platform default).
  ///
  /// - H.264, the legacy format: so the GPL Android build
  ///   stays libx264 and iOS VideoToolbox (several times faster, and the
  ///   only one that can ship on the App Store);
  /// - H.264, any other format: MediaCodec before libx264 on Android (no
  ///   earlier output to stay identical with, and software 4K is unusable);
  /// - HEVC: VideoToolbox on iOS, MediaCodec on Android, never libx265.
  VideoEncoder encoderFor(ClipFormat format) {
    final List<VideoEncoder> preferences = switch ((
      format.codec,
      format.isLegacy,
      _isIOS,
    )) {
      (VideoCodec.h264, _, true) => const <VideoEncoder>[
        VideoEncoder.videoToolbox,
        VideoEncoder.libx264,
        VideoEncoder.mediaCodec,
      ],
      (VideoCodec.h264, true, false) => const <VideoEncoder>[
        VideoEncoder.libx264,
        VideoEncoder.mediaCodec,
        VideoEncoder.videoToolbox,
      ],
      (VideoCodec.h264, false, false) => const <VideoEncoder>[
        VideoEncoder.mediaCodec,
        VideoEncoder.libx264,
        VideoEncoder.videoToolbox,
      ],
      (VideoCodec.hevc, _, true) => const <VideoEncoder>[
        VideoEncoder.hevcVideoToolbox,
        VideoEncoder.hevcMediaCodec,
      ],
      (VideoCodec.hevc, _, false) => const <VideoEncoder>[
        VideoEncoder.hevcMediaCodec,
        VideoEncoder.hevcVideoToolbox,
      ],
    };
    for (final VideoEncoder candidate in preferences) {
      if (_available.contains(candidate.ffmpegName)) return candidate;
    }
    return preferences.first;
  }

  /// The encoder of the legacy format (`ClipFormat.legacy`).
  VideoEncoder get legacyEncoder =>
      encoderFor(const ClipFormat.legacy(VideoOrientation.landscape));

  /// The encoder of an HEVC format.
  VideoEncoder get hevcEncoder => encoderFor(
    const ClipFormat(
      tier: ResolutionTier.p1080,
      orientation: VideoOrientation.landscape,
      codec: VideoCodec.hevc,
      fps: FrameRate.f30,
      channels: AudioChannels.stereo,
      range: DynamicRange.sdr,
    ),
  );

  /// The encoder names in `ffmpeg -encoders` output, whose rows look like
  /// ` V....D libx264              libx264 H.264 / AVC ...`. Lines are split
  /// as `LineSplitter` does (CR, LF or CRLF).
  static Set<String> parseEncoders(String encodersOutput) => <String>{
    for (final String line in const LineSplitter().convert(encodersOutput))
      if (_row.firstMatch(line) case final RegExpMatch match) match.group(1)!,
  };

  /// The `-c:v` arguments and quality target of [encoder] for [format].
  ///
  /// - libx264: `-crf 20 -preset medium` (`medium` is 2–3× faster than
  ///   `slow` and visually the same at this quality);
  /// - the hardware encoders never get `-crf` or `-preset` (ffmpeg fails
  ///   with them) and take `-b:v` from `EncoderPolicy.bitrateFor` (12000k
  ///   for the legacy format, as before); VideoToolbox also `-profile:v`
  ///   (`high` for H.264, `main` for HEVC, `main10` for HLG) and
  ///   `-allow_sw 1`, so a session falls back to the software encoder when
  ///   every hardware slot is busy (the simulator, and older devices while
  ///   the camera is still shutting down);
  /// - HLG is HEVC Main10 on both hardware encoders:
  ///   `-profile:v main10` here, the 10-bit pixel format and the BT.2020
  ///   colour tags in `ClipEncoding.outputPixelFormat`.
  ///
  /// An encoder of another codec than the format's, or an invalid format
  /// (`ClipFormat.isValid`: H.264 with HLG), is an [ArgumentError].
  static List<String> argumentsFor(VideoEncoder encoder, ClipFormat format) {
    if (encoder.codec != format.codec) {
      throw ArgumentError.value(
        encoder,
        'encoder',
        'writes ${encoder.codec.token}, the format is ${format.codec.token}',
      );
    }
    if (!format.isValid) {
      throw ArgumentError.value(format, 'format', 'H.264 cannot carry HLG');
    }
    final String bitrate = '${EncoderPolicy.bitrateFor(format) ~/ 1000}k';
    final String hevcProfile = switch (format.range) {
      DynamicRange.sdr => 'main',
      DynamicRange.hlg => 'main10',
    };
    return switch (encoder) {
      VideoEncoder.libx264 => <String>[
        '-c:v',
        encoder.ffmpegName,
        '-crf',
        '20',
        '-preset',
        'medium',
      ],
      VideoEncoder.videoToolbox => <String>[
        '-c:v',
        encoder.ffmpegName,
        '-b:v',
        bitrate,
        '-profile:v',
        'high',
        '-allow_sw',
        '1',
      ],
      VideoEncoder.hevcVideoToolbox => <String>[
        '-c:v',
        encoder.ffmpegName,
        '-b:v',
        bitrate,
        '-profile:v',
        hevcProfile,
        '-allow_sw',
        '1',
      ],
      VideoEncoder.mediaCodec => <String>[
        '-c:v',
        encoder.ffmpegName,
        '-b:v',
        bitrate,
      ],
      // SDR names no profile; HLG names Main10
      // so the wrapper asks MediaCodec for a 10-bit session rather than
      // deciding from the input alone.
      VideoEncoder.hevcMediaCodec => <String>[
        '-c:v',
        encoder.ffmpegName,
        '-b:v',
        bitrate,
        if (format.range == DynamicRange.hlg) ...<String>[
          '-profile:v',
          hevcProfile,
        ],
      ],
    };
  }

  static final RegExp _row = RegExp(r'^\s*[VAS][A-Z.]{5}\s+([A-Za-z0-9_]+)\s');
}
