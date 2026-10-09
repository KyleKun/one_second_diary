import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/encoder_catalog.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

/// `ffmpeg -hide_banner -encoders` of the GPL iOS build (libx264 and the
/// platform's hardware encoders).
const String gplIos = '''
Encoders:
 V..... = Video
 ------
 V....D libx264              libx264 H.264 / AVC / MPEG-4 AVC (codec h264)
 V....D h264_videotoolbox    VideoToolbox H.264 Encoder (codec h264)
 V....D hevc_videotoolbox    VideoToolbox H.265 Encoder (codec hevc)
 A....D aac                  AAC (Advanced Audio Coding)
 S..... mov_text             3GPP Timed Text subtitle
''';

/// The GPL Android build: libx264 and MediaCodec for both codecs.
const String gplAndroid = '''
Encoders:
 V....D libx264              libx264 H.264 / AVC / MPEG-4 AVC (codec h264)
 V....D h264_mediacodec      MediaCodec H.264 encoder (codec h264)
 V....D hevc_mediacodec      MediaCodec HEVC encoder (codec hevc)
 V....D libx265              libx265 H.265 / HEVC (codec hevc)
 A....D aac                  AAC (Advanced Audio Coding)
''';

/// The LGPL Android build: no libx264, only MediaCodec.
const String lgplAndroid = '''
Encoders:
 V..... = Video
 ------
 V....D h264_mediacodec      MediaCodec H.264 encoder (codec h264)
 V....D mpeg4                MPEG-4 part 2
 A....D aac                  AAC (Advanced Audio Coding)
''';

const ClipFormat legacy = ClipFormat.legacy(VideoOrientation.landscape);

ClipFormat formatOf(
  VideoCodec codec, {
  ResolutionTier tier = ResolutionTier.p1080,
  FrameRate fps = FrameRate.f30,
  DynamicRange range = DynamicRange.sdr,
}) => ClipFormat(
  tier: tier,
  orientation: VideoOrientation.landscape,
  codec: codec,
  fps: fps,
  channels: AudioChannels.stereo,
  range: range,
);

void main() {
  // The legacy format picks: iOS VideoToolbox > libx264 > MediaCodec; Android libx264 >
  // MediaCodec > VideoToolbox; an empty or failed probe keeps the platform default.
  test('the legacy format picks what v1.7 picked for every probe output', () {
    for (final ProbeCase probe in probeCases) {
      expect(
        (
          EncoderCatalog.of(probe.output, isIOS: false).encoderFor(legacy),
          EncoderCatalog.of(probe.output, isIOS: true).encoderFor(legacy),
        ),
        (probe.android, probe.ios),
        reason: probe.output,
      );
    }
  });

  test('reads encoder names, not decoders or headers, splitting CR, LF and '
      'CRLF lines like v1.7 (LineSplitter)', () {
    for (final ProbeCase probe in probeCases) {
      expect(
        EncoderCatalog.parseEncoders(probe.output),
        probe.encoders,
        reason: probe.output,
      );
    }
  });

  // HEVC takes the platform's hardware encoder and never libx265; any other H.264 format
  // takes MediaCodec before libx264 on Android (software 4K is unusable), VideoToolbox on iOS.
  test('per codec and build: HEVC never libx265; non-legacy H.264 prefers '
      'MediaCodec on Android', () {
    final ClipFormat hevc = formatOf(VideoCodec.hevc);
    final ClipFormat h264FourK = formatOf(
      VideoCodec.h264,
      tier: ResolutionTier.p2160,
    );
    final EncoderCatalog android = EncoderCatalog.of(gplAndroid, isIOS: false);
    expect(android.encoderFor(legacy), VideoEncoder.libx264);
    expect(android.encoderFor(h264FourK), VideoEncoder.mediaCodec);
    expect(android.encoderFor(hevc), VideoEncoder.hevcMediaCodec);
    expect(android.legacyEncoder, VideoEncoder.libx264);
    expect(android.hevcEncoder, VideoEncoder.hevcMediaCodec);

    final EncoderCatalog ios = EncoderCatalog.of(gplIos, isIOS: true);
    expect(ios.encoderFor(legacy), VideoEncoder.videoToolbox);
    expect(ios.encoderFor(h264FourK), VideoEncoder.videoToolbox);
    expect(ios.encoderFor(hevc), VideoEncoder.hevcVideoToolbox);

    // Without a MediaCodec H.264 wrapper a non-legacy format falls back
    // to libx264; without any HEVC encoder the platform's is the default
    // (the phone check marks what really works).
    final EncoderCatalog x264Only = EncoderCatalog.of(
      ' V....D libx264              libx264 H.264\n',
      isIOS: false,
    );
    expect(x264Only.encoderFor(h264FourK), VideoEncoder.libx264);
    expect(x264Only.encoderFor(hevc), VideoEncoder.hevcMediaCodec);
    expect(
      EncoderCatalog.of('', isIOS: true).encoderFor(hevc),
      VideoEncoder.hevcVideoToolbox,
    );
    expect(
      EncoderCatalog.of(lgplAndroid, isIOS: false).encoderFor(h264FourK),
      VideoEncoder.mediaCodec,
    );
  });

  // GOLDEN. The hardware encoders never get -crf or -preset, which makes ffmpeg fail.
  // libx264 takes `-preset medium`; the hardware encoders' `-b:v` comes from the bitrate
  // table (12000k for the legacy format).
  test('EncoderCatalog.argumentsFor: the literal args of each encoder for '
      'the legacy format', () {
    expect(
      <VideoEncoder, List<String>>{
        for (final VideoEncoder encoder in <VideoEncoder>[
          VideoEncoder.libx264,
          VideoEncoder.videoToolbox,
          VideoEncoder.mediaCodec,
        ])
          encoder: EncoderCatalog.argumentsFor(encoder, legacy),
      },
      <VideoEncoder, List<String>>{
        VideoEncoder.libx264: <String>[
          '-c:v', 'libx264', '-crf', '20', '-preset', 'medium', //
        ],
        VideoEncoder.videoToolbox: <String>[
          '-c:v', 'h264_videotoolbox', '-b:v', '12000k', //
          '-profile:v', 'high', '-allow_sw', '1',
        ],
        VideoEncoder.mediaCodec: <String>[
          '-c:v', 'h264_mediacodec', '-b:v', '12000k', //
        ],
      },
    );
  });

  test('the HEVC and non-legacy arguments: the format\'s bitrate, main '
      'profile on VideoToolbox', () {
    final ClipFormat ultra = formatOf(
      VideoCodec.hevc,
      tier: ResolutionTier.p2160,
      fps: FrameRate.f60,
    );
    expect(
      EncoderCatalog.argumentsFor(VideoEncoder.hevcVideoToolbox, ultra),
      <String>[
        '-c:v', 'hevc_videotoolbox', '-b:v', '42000k', //
        '-profile:v', 'main', '-allow_sw', '1',
      ],
    );
    expect(
      EncoderCatalog.argumentsFor(VideoEncoder.hevcMediaCodec, ultra),
      <String>['-c:v', 'hevc_mediacodec', '-b:v', '42000k'],
    );
    expect(
      EncoderCatalog.argumentsFor(
        VideoEncoder.hevcMediaCodec,
        formatOf(VideoCodec.hevc),
      ),
      <String>['-c:v', 'hevc_mediacodec', '-b:v', '8000k'],
    );
    expect(
      EncoderCatalog.argumentsFor(
        VideoEncoder.mediaCodec,
        formatOf(VideoCodec.h264, tier: ResolutionTier.p720),
      ),
      <String>['-c:v', 'h264_mediacodec', '-b:v', '5000k'],
    );
    expect(
      EncoderCatalog.argumentsFor(
        VideoEncoder.videoToolbox,
        formatOf(VideoCodec.h264, tier: ResolutionTier.p1440),
      ),
      <String>[
        '-c:v', 'h264_videotoolbox', '-b:v', '20000k', //
        '-profile:v', 'high', '-allow_sw', '1',
      ],
    );
    // libx264 keeps crf whatever the tier.
    expect(
      EncoderCatalog.argumentsFor(
        VideoEncoder.libx264,
        formatOf(VideoCodec.h264, tier: ResolutionTier.p2160),
      ),
      <String>['-c:v', 'libx264', '-crf', '20', '-preset', 'medium'],
    );
  });

  // GOLDEN: HLG is HEVC Main10 on both hardware encoders, at the HLG bitrate (x1.2).
  // H.264 cannot carry HLG: refused like a codec mismatch.
  test('HLG: Main10 on VideoToolbox and MediaCodec at the HLG bitrate; '
      'H.264 with HLG, or an encoder of the other codec, is refused', () {
    expect(
      EncoderCatalog.argumentsFor(
        VideoEncoder.hevcVideoToolbox,
        formatOf(VideoCodec.hevc, range: DynamicRange.hlg),
      ),
      <String>[
        '-c:v', 'hevc_videotoolbox', '-b:v', '9600k', //
        '-profile:v', 'main10', '-allow_sw', '1',
      ],
    );
    expect(
      EncoderCatalog.argumentsFor(
        VideoEncoder.hevcMediaCodec,
        formatOf(
          VideoCodec.hevc,
          tier: ResolutionTier.p2160,
          range: DynamicRange.hlg,
        ),
      ),
      <String>[
        '-c:v',
        'hevc_mediacodec',
        '-b:v',
        '33600k',
        '-profile:v',
        'main10',
      ],
    );
    expect(
      () => EncoderCatalog.argumentsFor(
        VideoEncoder.mediaCodec,
        formatOf(VideoCodec.h264, range: DynamicRange.hlg),
      ),
      throwsArgumentError,
    );
    expect(
      () => EncoderCatalog.argumentsFor(
        VideoEncoder.libx264,
        formatOf(VideoCodec.hevc),
      ),
      throwsArgumentError,
    );
    expect(
      () => EncoderCatalog.argumentsFor(VideoEncoder.hevcMediaCodec, legacy),
      throwsArgumentError,
    );
  });
}

typedef ProbeCase = ({
  String output,
  VideoEncoder android,
  VideoEncoder ios,
  Set<String> encoders,
});

/// Probe outputs with the legacy encoder picked on each platform and the
/// encoder names read.
const List<ProbeCase> probeCases = <ProbeCase>[
  (
    output: '',
    android: VideoEncoder.libx264,
    ios: VideoEncoder.videoToolbox,
    encoders: <String>{},
  ),
  (
    output: gplIos,
    android: VideoEncoder.libx264,
    ios: VideoEncoder.videoToolbox,
    encoders: <String>{
      'libx264',
      'h264_videotoolbox',
      'hevc_videotoolbox',
      'aac',
      'mov_text',
    },
  ),
  (
    output: lgplAndroid,
    android: VideoEncoder.mediaCodec,
    ios: VideoEncoder.mediaCodec,
    encoders: <String>{'h264_mediacodec', 'mpeg4', 'aac'},
  ),
  (
    output: ' V....D libx264              libx264 H.264\n',
    android: VideoEncoder.libx264,
    ios: VideoEncoder.libx264,
    encoders: <String>{'libx264'},
  ),
  (
    output:
        ' V....D libx264              libx264 H.264\r'
        ' V....D h264_mediacodec      MediaCodec H.264\r',
    android: VideoEncoder.libx264,
    ios: VideoEncoder.libx264,
    encoders: <String>{'libx264', 'h264_mediacodec'},
  ),
  (
    output:
        ' V....D h264_videotoolbox    VT\r\n V....D h264_mediacodec  MC\r\n',
    android: VideoEncoder.mediaCodec,
    ios: VideoEncoder.videoToolbox,
    encoders: <String>{'h264_videotoolbox', 'h264_mediacodec'},
  ),
  (
    output: 'V....D libx264 x\nnot a row\n VFS..D h264_mediacodec MC\n',
    android: VideoEncoder.libx264,
    ios: VideoEncoder.libx264,
    encoders: <String>{'libx264', 'h264_mediacodec'},
  ),
  (
    output: ' A....D aac  AAC\n S..... mov_text  3GPP\n',
    android: VideoEncoder.libx264,
    ios: VideoEncoder.videoToolbox,
    encoders: <String>{'aac', 'mov_text'},
  ),
  // No trailing whitespace after the name: no match.
  (
    output: ' V....D libx264',
    android: VideoEncoder.libx264,
    ios: VideoEncoder.videoToolbox,
    encoders: <String>{},
  ),
];
