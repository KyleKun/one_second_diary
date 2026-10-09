import 'package:equatable/equatable.dart';

/// Where a clip's video can be cut without re-encoding: its frame count and
/// the display indices of its keyframes (sync samples), read by one ffprobe
/// pass over the packets (`ProbeCommands.keyframes`,
/// `KeyframeProbeParser`).
///
/// A movie with transitions copies each clip's body between two keyframes
/// and re-encodes only the frames outside them (`TransitionPolicy`). Every
/// clip has a keyframe at 0; newer clips carry two more
/// (`ClipEncoding.forcedKeyframes`), and VideoToolbox writes one every 12
/// frames of its own accord. A clip with only `[0]` cannot be cut and joins
/// with a hard cut.
final class ClipKeyframes extends Equatable {
  const ClipKeyframes({required this.frameCount, required this.indices});

  /// Video frames in the clip (packets of the video stream).
  final int frameCount;

  /// Display indices (0-based, by presentation time) of the keyframes, in
  /// ascending order, 0 first for any playable clip.
  final List<int> indices;

  @override
  List<Object?> get props => <Object?>[frameCount, indices];
}
