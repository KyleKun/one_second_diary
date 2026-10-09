import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/transition_policy.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';

void main() {
  const FrameRate f30 = FrameRate.f30;
  const FrameRate f60 = FrameRate.f60;

  // The policy is time-based (267 ms transition, 333 ms keyframe margin) and counted in
  // frames at the movie's rate: 8 and 10 frames at 30 fps, double at 60.
  test('frames from time: 8/10 at 30 fps, 16/20 at 60 fps', () {
    expect(
      (TransitionPolicy.frames(f30), TransitionPolicy.keyframeMargin(f30)),
      (8, 10),
    );
    expect(
      (TransitionPolicy.frames(f60), TransitionPolicy.keyframeMargin(f60)),
      (16, 20),
    );
  });

  // A forced keyframe takes the FIRST frame at or after its time, so the times are rounded
  // down (1.6667 would land on frame 51); a stream-copy seek must name the keyframe's time
  // to the microsecond (0.3333 seeks to the keyframe before, 0.3500 leaves the first frame
  // at -33 ms); a decode seek drops the frames before its time, so rounded down keeps the
  // keyframe.
  test('the ffmpeg time strings of each rule at 30 fps (unchanged)', () {
    expect(
      TransitionPolicy.forcedKeyframeTimes(2000, fps: f30),
      '0.3333,1.6666',
    );
    expect(
      TransitionPolicy.forcedKeyframeTimes(1500, fps: f30),
      '0.3333,1.1666',
    );
    expect(
      TransitionPolicy.forcedKeyframeTimes(1000, fps: f30),
      '0.3333,0.6666',
    );
    expect(
      TransitionPolicy.forcedKeyframeTimes(10500, fps: f30),
      '0.3333,10.1666',
    );
    expect(TransitionPolicy.forcedKeyframeTimes(600, fps: f30), isNull);
    expect(TransitionPolicy.seekForCopy(10, fps: f30), '0.333333');
    expect(TransitionPolicy.seekForCopy(35, fps: f30), '1.166667');
    expect(TransitionPolicy.seekForDecode(50, fps: f30), '1.6666');
    expect(TransitionPolicy.seekForDecode(9, fps: f30), '0.3000');
    expect(TransitionPolicy.seconds(8, fps: f30), '0.266667');
    expect(TransitionPolicy.seconds(12, fps: f30), '0.400000');
    expect(TransitionPolicy.durationSeconds(f30), '0.266667');
  });

  // At 60 fps the keyframes sit 20 frames in (the same 333 ms) and the
  // transition lasts 16 frames (the same 267 ms): the time strings are
  // the frame's time at 60.
  test('the ffmpeg time strings at 60 fps', () {
    expect(
      TransitionPolicy.forcedKeyframeTimes(2000, fps: f60),
      '0.3333,1.6666',
    );
    expect(
      TransitionPolicy.forcedKeyframeTimes(1500, fps: f60),
      '0.3333,1.1666',
    );
    expect(
      TransitionPolicy.forcedKeyframeTimes(1000, fps: f60),
      '0.3333,0.6666',
    );
    expect(TransitionPolicy.forcedKeyframeTimes(600, fps: f60), isNull);
    expect(TransitionPolicy.seekForCopy(20, fps: f60), '0.333333');
    expect(TransitionPolicy.seekForCopy(70, fps: f60), '1.166667');
    expect(TransitionPolicy.seekForCopy(21, fps: f60), '0.350000');
    expect(TransitionPolicy.seekForDecode(100, fps: f60), '1.6666');
    expect(TransitionPolicy.seekForDecode(19, fps: f60), '0.3166');
    expect(TransitionPolicy.seconds(16, fps: f60), '0.266667');
    expect(TransitionPolicy.seconds(24, fps: f60), '0.400000');
    expect(TransitionPolicy.durationSeconds(f60), '0.266667');
  });

  // The head cut is the first keyframe at least a transition in; the tail
  // cut the last one at least a transition before the end and after the
  // head cut, so the body keeps a frame.
  test('head and tail cuts from the keyframes at 30 fps', () {
    const ClipKeyframes saved = ClipKeyframes(
      frameCount: 45,
      indices: <int>[0, 10, 35],
    );
    expect(TransitionPolicy.headCut(saved, fps: f30), 10);
    expect(TransitionPolicy.tailCut(saved, headCut: 10, fps: f30), 35);
    expect(TransitionPolicy.isReady(saved), isTrue);

    // VideoToolbox: its own keyframe every 12 frames.
    const ClipKeyframes toolbox = ClipKeyframes(
      frameCount: 45,
      indices: <int>[0, 12, 24, 36],
    );
    expect(TransitionPolicy.headCut(toolbox, fps: f30), 12);
    expect(TransitionPolicy.tailCut(toolbox, headCut: 12, fps: f30), 36);

    // A clip saved by libx264 without cut keyframes: one keyframe.
    const ClipKeyframes older = ClipKeyframes(
      frameCount: 45,
      indices: <int>[0],
    );
    expect(TransitionPolicy.headCut(older, fps: f30), isNull);
    expect(TransitionPolicy.tailCut(older, fps: f30), isNull);
    expect(TransitionPolicy.isReady(older), isFalse);

    // A 1 s clip: head 10, tail 20, a 10-frame body.
    const ClipKeyframes second = ClipKeyframes(
      frameCount: 30,
      indices: <int>[0, 10, 20],
    );
    expect(TransitionPolicy.tailCut(second, headCut: 10, fps: f30), 20);
    // Without a head cut the tail may be the keyframe at 10.
    expect(
      TransitionPolicy.tailCut(
        const ClipKeyframes(frameCount: 20, indices: <int>[0, 10]),
        fps: f30,
      ),
      10,
    );
    // A keyframe 7 frames before the end is too close for the tail.
    expect(
      TransitionPolicy.tailCut(
        const ClipKeyframes(frameCount: 30, indices: <int>[0, 23]),
        fps: f30,
      ),
      isNull,
    );
  });

  // A 60 fps clip saved by the app has keyframes 20 frames from each end
  // (333 ms); a transition needs 16 frames on each side.
  test('head and tail cuts at 60 fps', () {
    const ClipKeyframes saved = ClipKeyframes(
      frameCount: 90,
      indices: <int>[0, 20, 70],
    );
    expect(TransitionPolicy.headCut(saved, fps: f60), 20);
    expect(TransitionPolicy.tailCut(saved, headCut: 20, fps: f60), 70);
    expect(TransitionPolicy.isReady(saved, fps: f60), isTrue);

    // A keyframe 10 frames in is a whole transition at 30 but not at 60.
    const ClipKeyframes thirtyStyle = ClipKeyframes(
      frameCount: 90,
      indices: <int>[0, 10, 80],
    );
    expect(TransitionPolicy.headCut(thirtyStyle, fps: f60), 80);
    expect(TransitionPolicy.tailCut(thirtyStyle, headCut: 0, fps: f60), 10);
    expect(TransitionPolicy.isReady(thirtyStyle, fps: f60), isFalse);
    expect(TransitionPolicy.isReady(thirtyStyle), isTrue, reason: 'at 30');

    // A keyframe 15 frames before the end is too close at 60.
    expect(
      TransitionPolicy.tailCut(
        const ClipKeyframes(frameCount: 60, indices: <int>[0, 45]),
        fps: f60,
      ),
      isNull,
    );
  });
}
