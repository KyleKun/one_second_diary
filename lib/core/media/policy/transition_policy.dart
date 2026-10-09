import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';

/// The numbers behind movie transitions, time-based and
/// counted in frames at the clip format's rate, and the exact ffmpeg time
/// strings that cut at them.
///
/// A transition between clip A and clip B overlaps A's last [frames] frames
/// with B's first [frames]. To keep the join a stream copy, A's body is
/// copied up to a keyframe at least [frames] before its end, B's body from
/// a keyframe at least [frames] after its start, and only the frames
/// outside those keyframes (A's tail, B's head) are decoded, crossfaded and
/// encoded again. Every clip the app saves gets one keyframe
/// [keyframeMargin] frames from each end (`ClipEncoding.forcedKeyframes`), so
/// those cuts exist.
///
/// Times are written for ffmpeg's two seek rules, verified with ffmpeg 8:
/// - a forced keyframe lands on the FIRST frame at or after the given
///   time, so a time is rounded DOWN to 4 decimals (`1.6666` for frame 50
///   at 1.666666…; `1.6667` would land on frame 51);
/// - `-ss` before `-i` seeks to the last keyframe at or before the time,
///   rounding the time to the nearest sample, and shifts every timestamp
///   by the time given. A STREAM COPY needs both to land on the keyframe
///   exactly (its first frame must sit at 0, or the concat overlaps the
///   files), so the time is the keyframe's own, to the microsecond
///   ([seekForCopy], `0.333333` for frame 10): a time rounded down seeks to
///   the keyframe before, and a time past it leaves the first frame at a
///   negative time. For a DECODE ffmpeg drops the decoded frames before the
///   time, so the time is rounded DOWN ([seekForDecode], `1.6666` for frame
///   50) and the keyframe itself is kept; output times start at 0 anyway.
abstract final class TransitionPolicy {
  /// A transition's length: 267 ms (8 frames at 30, 16 at 60). A dissolve
  /// shorter than this reads as a cut; a longer one eats a 1 s clip.
  static const int transitionMs = 267;

  /// Where the save forces a keyframe from each end of a clip: 333 ms (10
  /// frames at 30, 20 at 60), so the tail keeps [frames] frames even when
  /// the output is a frame short of its planned length.
  static const int keyframeMarginMs = 333;

  /// How many clips one audio pass takes before the rest go to another
  /// (`TransitionCommands.audio`): iOS allows 256 open files per process
  /// and every input costs a few.
  static const int audioChunkClips = 40;

  /// [transitionMs] in frames at [fps]: 8 at 30, 16 at 60.
  static int frames(FrameRate fps) => _framesOf(transitionMs, fps);

  /// [keyframeMarginMs] in frames at [fps]: 10 at 30, 20 at 60.
  static int keyframeMargin(FrameRate fps) => _framesOf(keyframeMarginMs, fps);

  static int _framesOf(int ms, FrameRate fps) =>
      (ms * fps.value / 1000).round();

  /// [frames] as the `xfade`/`acrossfade` duration, in seconds.
  static String durationSeconds(FrameRate fps) =>
      seconds(frames(fps), fps: fps);

  /// [count] frames at [fps] as seconds with 6 decimals (`0.266667`), for
  /// filter arguments and concat `duration` lines.
  static String seconds(int count, {required FrameRate fps}) =>
      (count / fps.value).toStringAsFixed(6);

  /// The `-force_key_frames` value for a clip [durationMs] long at [fps]:
  /// the frame [keyframeMargin] in, and the one [keyframeMargin] before the
  /// end, as times rounded down to 4 decimals (`0.3333,1.6666` for a 2 s
  /// clip at 30). Null for a clip too short to hold both (under 1 s, which
  /// the app never saves).
  static String? forcedKeyframeTimes(int durationMs, {required FrameRate fps}) {
    final int frameCount = (durationMs * fps.value / 1000).round();
    final int margin = keyframeMargin(fps);
    final int tail = frameCount - margin;
    if (tail <= margin) return null;
    return '${_floorSeconds(margin, fps)},${_floorSeconds(tail, fps)}';
  }

  /// The `-ss` time that makes a STREAM COPY start at keyframe [index]: its
  /// own time to the microsecond (6 decimals, nearest).
  static String seekForCopy(int index, {required FrameRate fps}) =>
      (index / fps.value).toStringAsFixed(6);

  /// The `-ss` time that makes a DECODE start at keyframe [index]: its own
  /// time rounded down to 4 decimals.
  static String seekForDecode(int index, {required FrameRate fps}) =>
      _floorSeconds(index, fps);

  /// The keyframe a clip's body can start from, for a transition before it:
  /// the first keyframe at least [frames] in (so the head holds a whole
  /// transition) and before the last frame; null when there is none.
  static int? headCut(ClipKeyframes keyframes, {required FrameRate fps}) {
    final int transition = frames(fps);
    for (final int index in keyframes.indices) {
      if (index >= transition && index < keyframes.frameCount) return index;
    }
    return null;
  }

  /// The keyframe a clip's body can end at, for a transition after it: the
  /// last keyframe at least [frames] before the end and after [headCut]
  /// (the body keeps at least one frame; 0 without a head cut); null when
  /// there is none.
  static int? tailCut(
    ClipKeyframes keyframes, {
    int headCut = 0,
    required FrameRate fps,
  }) {
    final int transition = frames(fps);
    int? found;
    for (final int index in keyframes.indices) {
      if (index > headCut && keyframes.frameCount - index >= transition) {
        found = index;
      }
    }
    return found;
  }

  /// Whether a clip can take a transition on both sides at [fps] (the
  /// legacy 30 fps unless given: the one reader outside the engine, the
  /// Create movie cubit, passes the profile's rate).
  static bool isReady(
    ClipKeyframes keyframes, {
    FrameRate fps = FrameRate.f30,
  }) {
    final int? head = headCut(keyframes, fps: fps);
    return head != null && tailCut(keyframes, headCut: head, fps: fps) != null;
  }

  /// Frame [index]'s time at [fps] rounded DOWN to 4 decimals.
  static String _floorSeconds(int index, FrameRate fps) {
    final int tenThousandths = index * 10000 ~/ fps.value;
    final String whole = (tenThousandths ~/ 10000).toString();
    final String fraction = (tenThousandths % 10000).toString().padLeft(4, '0');
    return '$whole.$fraction';
  }
}
