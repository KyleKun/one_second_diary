import 'package:one_second_diary/core/media/types/clip_keyframes.dart';

/// Reads the output of `ProbeCommands.keyframes` (`ffprobe -select_streams
/// v:0 -show_entries packet=pts_time,flags -of csv=p=0`): one line per
/// video packet in decoding order, `<pts_time>,<flags>`, where the flags
/// start with `K` for a keyframe (`0.300000,K__`, `0.333333,___`).
///
/// Indices are DISPLAY positions: a packet's rank by presentation time.
/// That is what a stream-copy cut counts (`-frames:v`), since every frame
/// shown before a keyframe is also decoded before it.
abstract final class KeyframeProbeParser {
  /// The keyframes in [output]; a clip with no video packets has
  /// `frameCount` 0 and no indices. Lines that are not `<time>,<flags>`
  /// are skipped.
  static ClipKeyframes parse(String output) {
    final List<(double, bool)> packets = <(double, bool)>[];
    for (final String line in output.split('\n')) {
      final List<String> parts = line.trim().split(',');
      if (parts.length < 2) continue;
      final double? pts = double.tryParse(parts[0]);
      if (pts == null) continue;
      packets.add((pts, parts[1].startsWith('K')));
    }
    packets.sort(((double, bool) a, (double, bool) b) => a.$1.compareTo(b.$1));
    return ClipKeyframes(
      frameCount: packets.length,
      indices: List<int>.unmodifiable(<int>[
        for (final (int index, (double, bool) packet) in packets.indexed)
          if (packet.$2) index,
      ]),
    );
  }
}
