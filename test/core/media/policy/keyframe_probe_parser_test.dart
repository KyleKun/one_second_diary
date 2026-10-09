import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/keyframe_probe_parser.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';

void main() {
  // ffprobe lists packets in DECODING order: with B-frames the keyframe at
  // display frame 10 comes before the two B-frames shown before it. The
  // index is the rank by presentation time, which is what `-frames:v`
  // counts.
  test('keyframe indices are display ranks, from packets in decode order', () {
    const String output =
        '0.000000,K__\n'
        '0.100000,___\n'
        '0.033333,___\n'
        '0.066667,___\n'
        '0.333333,K__\n' // decoded before the frames shown at 0.133..0.3
        '0.133333,___\n'
        '0.166667,___\n'
        '0.200000,___\n'
        '0.233333,___\n'
        '0.266667,___\n'
        '0.300000,___\n'
        '0.366667,___\r\n' // CRLF, as ffmpeg-kit may hand it over
        '0.400000,___\n';
    expect(
      KeyframeProbeParser.parse(output),
      const ClipKeyframes(frameCount: 13, indices: <int>[0, 10]),
    );
  });

  test('no video packets, or junk, is an empty clip', () {
    expect(
      KeyframeProbeParser.parse(''),
      const ClipKeyframes(frameCount: 0, indices: <int>[]),
    );
    expect(
      KeyframeProbeParser.parse('not,a\nnumber\n\n'),
      const ClipKeyframes(frameCount: 0, indices: <int>[]),
    );
  });
}
