import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/commands/calibration_commands.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

import '../../../support/track_1a/platform_layouts.dart';

const ClipFormat _ultra = ClipFormat(
  tier: ResolutionTier.p2160,
  orientation: VideoOrientation.landscape,
  codec: VideoCodec.hevc,
  fps: FrameRate.f60,
  channels: AudioChannels.stereo,
  range: DynamicRange.sdr,
);

/// The HLG output settings: 10-bit p010le, the BT.2100 tags, hvc1.
const List<String> hlgOutput = <String>[
  '-pix_fmt', 'p010le', //
  '-color_primaries', 'bt2020', '-color_trc', 'arib-std-b67',
  '-colorspace', 'bt2020nc',
  '-tag:v', 'hvc1',
];

/// 1080p30 HEVC stereo HLG, landscape.
const ClipFormat hlg1080 = ClipFormat(
  tier: ResolutionTier.p1080,
  orientation: VideoOrientation.landscape,
  codec: VideoCodec.hevc,
  fps: FrameRate.f30,
  channels: AudioChannels.stereo,
  range: DynamicRange.hlg,
);

void main() {
  // GOLDEN: one second of testsrc2 at the canvas and rate with anullsrc in the format's
  // layout, both bounded by -t 1, encoded with the format's exact save settings.
  test('encodeTest: one second of a test pattern with the format\'s exact '
      'encode settings, one per candidate class', () {
    final String out = '${android.cache}/scratch/job-1/encode-0.mp4';
    expect(
      CalibrationCommands.encodeTest(
        format: const ClipFormat.legacy(VideoOrientation.landscape),
        encoder: VideoEncoder.libx264,
        output: out,
      ),
      <String>[
        '-f', 'lavfi', '-i', 'testsrc2=size=1920x1080:rate=30', //
        '-f', 'lavfi', '-i', 'anullsrc=channel_layout=mono:sample_rate=48000',
        '-t', '1',
        '-r', '30', '-ac', '1', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-c:v', 'libx264', '-crf', '20', '-preset', 'medium',
        '-pix_fmt', 'yuv420p',
        '-map', '0:v', '-map', '1:a',
        out, '-y',
      ],
      reason: 'the legacy format, the first candidate',
    );
    expect(
      CalibrationCommands.encodeTest(
        format: _ultra,
        encoder: VideoEncoder.hevcVideoToolbox,
        output: '${ios.cache}/scratch job/encode-5.mp4',
      ),
      <String>[
        '-f', 'lavfi', '-i', 'testsrc2=size=3840x2160:rate=60', //
        '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
        '-t', '1',
        '-r', '60', '-ac', '2', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-c:v', 'hevc_videotoolbox', '-b:v', '42000k',
        '-profile:v', 'main', '-allow_sw', '1',
        '-pix_fmt', 'yuv420p', '-tag:v', 'hvc1',
        '-map', '0:v', '-map', '1:a',
        '${ios.cache}/scratch job/encode-5.mp4', '-y',
      ],
      reason: '4K60 HEVC stereo on iOS, the path with a space whole',
    );
    expect(
      CalibrationCommands.encodeTest(
        format: const ClipFormat(
          tier: ResolutionTier.p1440,
          orientation: VideoOrientation.landscape,
          codec: VideoCodec.hevc,
          fps: FrameRate.f30,
          channels: AudioChannels.stereo,
          range: DynamicRange.sdr,
        ),
        encoder: VideoEncoder.hevcMediaCodec,
        output: out,
      ),
      containsAllInOrder(<String>[
        'testsrc2=size=2560x1440:rate=30',
        '-c:v',
        'hevc_mediacodec',
        '-b:v',
        '13000k',
      ]),
    );
  });

  test('decodeTest: the sample decoded into nothing', () {
    expect(
      CalibrationCommands.decodeTest(
        sample: '${ios.internal}/calibration/iphone-4k60.mp4',
      ),
      <String>[
        '-i', '${ios.internal}/calibration/iphone-4k60.mp4', //
        '-f', 'null', '-',
      ],
    );
  });

  // GOLDEN: HLG candidates feed the encoder 10-bit frames (`-vf format=yuv420p10le`,
  // testsrc2 being 8-bit) with the HLG encode settings: Main10, p010le, BT.2100 tags, HLG bitrate.
  test('encodeTest: an HLG candidate hands the encoder 10-bit frames with '
      'the HLG settings (1080p MediaCodec, 2160p VideoToolbox)', () {
    final String out = '${android.cache}/scratch/job-1/encode-7.mp4';
    expect(
      CalibrationCommands.encodeTest(
        format: hlg1080,
        encoder: VideoEncoder.hevcMediaCodec,
        output: out,
      ),
      <String>[
        '-f', 'lavfi', '-i', 'testsrc2=size=1920x1080:rate=30', //
        '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
        '-t', '1',
        '-vf', 'format=yuv420p10le',
        '-r', '30', '-ac', '2', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-c:v', 'hevc_mediacodec', '-b:v', '9600k', '-profile:v', 'main10',
        ...hlgOutput,
        '-map', '0:v', '-map', '1:a',
        out, '-y',
      ],
    );
    expect(
      CalibrationCommands.encodeTest(
        format: const ClipFormat(
          tier: ResolutionTier.p2160,
          orientation: VideoOrientation.landscape,
          codec: VideoCodec.hevc,
          fps: FrameRate.f30,
          channels: AudioChannels.stereo,
          range: DynamicRange.hlg,
        ),
        encoder: VideoEncoder.hevcVideoToolbox,
        output: '${ios.cache}/scratch job/encode-8.mp4',
      ),
      <String>[
        '-f', 'lavfi', '-i', 'testsrc2=size=3840x2160:rate=30', //
        '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
        '-t', '1',
        '-vf', 'format=yuv420p10le',
        '-r', '30', '-ac', '2', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-c:v', 'hevc_videotoolbox', '-b:v', '33600k',
        '-profile:v', 'main10', '-allow_sw', '1',
        ...hlgOutput,
        '-map', '0:v', '-map', '1:a',
        '${ios.cache}/scratch job/encode-8.mp4', '-y',
      ],
    );
  });
}
