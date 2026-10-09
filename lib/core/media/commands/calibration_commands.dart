import 'package:one_second_diary/core/media/commands/clip_encoding.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';

/// The ffmpeg jobs of the phone check: what
/// this phone can encode, and how fast, measured on synthetic sources so
/// no asset is needed, and how fast it decodes a bundled real-world
/// sample. Every path is its own element.
abstract final class CalibrationCommands {
  /// One second of a test pattern (`testsrc2`, input 0) at [format]'s
  /// canvas and frame rate with silence in its layout (`anullsrc`, input
  /// 1), encoded into [output] with the format's exact encode settings
  /// (`ClipEncoding.encodeSettings`, the ones a save uses) by [encoder].
  /// `-t 1` bounds both infinite sources. Timed by `DeviceMediaCheck` for
  /// the real-time factor; its output is probed to confirm the encoder
  /// really wrote the format.
  ///
  /// `testsrc2` is 8-bit: an HLG candidate adds `-vf format=yuv420p10le`,
  /// so the encoder is handed 10-bit frames as a real HLG save hands them
  /// (an HDR import decoded 10-bit), and the timing is that save's. The
  /// SDR-to-HLG chain (`RangeFilter.sdrToHlg`) is not part of the test:
  /// it measures zimg, not the encoder, and the HLG profile is for
  /// imports. The SDR candidates' argv is unchanged.
  static List<String> encodeTest({
    required ClipFormat format,
    required VideoEncoder encoder,
    required String output,
  }) => <String>[
    '-f',
    'lavfi',
    '-i',
    'testsrc2=size=${format.width}x${format.height}:rate=${format.fpsValue}',
    ...ClipEncoding.silentAudioInput(format.channels),
    '-t',
    '1',
    if (format.range == DynamicRange.hlg) ...<String>[
      '-vf',
      'format=yuv420p10le',
    ],
    ...ClipEncoding.encodeSettings(format, encoder),
    '-map',
    '0:v',
    '-map',
    '1:a',
    output,
    '-y',
  ];

  /// Decodes the whole of [sample] (a bundled real-world recording) into
  /// nothing (`-f null -`): software decoding, timed by `DeviceMediaCheck`
  /// against the sample's length. Hardware decoding (`-hwaccel`) is not
  /// measured.
  static List<String> decodeTest({required String sample}) => <String>[
    '-i',
    sample,
    '-f',
    'null',
    '-',
  ];
}
