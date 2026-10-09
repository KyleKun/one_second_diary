import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/transition_plan.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';

const FrameRate _f30 = FrameRate.f30;
const FrameRate _f60 = FrameRate.f60;

/// A clip saved with cut keyframes: 10 in and 10 before the end.
({int? durationMs, ClipKeyframes? keyframes}) saved(int frames) => (
  durationMs: (frames * 1000 / 30).round(),
  keyframes: ClipKeyframes(
    frameCount: frames,
    indices: <int>[0, 10, frames - 10],
  ),
);

/// A clip saved by libx264 without them: one keyframe.
({int? durationMs, ClipKeyframes? keyframes}) older(int frames) => (
  durationMs: (frames * 1000 / 30).round(),
  keyframes: ClipKeyframes(frameCount: frames, indices: <int>[0]),
);

/// A 60 fps clip saved by the app: keyframes 20 in and 20 before the end.
({int? durationMs, ClipKeyframes? keyframes}) saved60(int frames) => (
  durationMs: (frames * 1000 / 60).round(),
  keyframes: ClipKeyframes(
    frameCount: frames,
    indices: <int>[0, 20, frames - 20],
  ),
);

void main() {
  // Three cut-able clips: the first keeps its start, the last its end, the
  // middle one is cut on both sides; every boundary is a transition; each
  // clip but the last loses the 8 overlapped frames in the movie.
  test('every boundary of cut-able clips is a transition, cut at the '
      'keyframes; lengths and chapters count the overlap once', () {
    final TransitionPlan plan = TransitionPlan.of(
      <({int? durationMs, ClipKeyframes? keyframes})>[
        saved(60),
        saved(45),
        saved(30),
      ],
      fps: _f30,
    );
    expect(plan.clips, const <PlannedClip>[
      PlannedClip(
        durationMs: 2000,
        frameCount: 60,
        headCut: 0,
        tailCut: 50,
        transitionAfter: true,
        fps: _f30,
      ),
      PlannedClip(
        durationMs: 1500,
        frameCount: 45,
        headCut: 10,
        tailCut: 35,
        transitionAfter: true,
        fps: _f30,
      ),
      PlannedClip(
        durationMs: 1000,
        frameCount: 30,
        headCut: 10,
        tailCut: null,
        transitionAfter: false,
        fps: _f30,
      ),
    ]);
    expect(plan.transitions, <bool>[true, true]);
    expect(plan.transitionCount, 2);
    expect(plan.hardCuts, 0);
    expect(plan.clips.map((PlannedClip c) => c.needsBody), <bool>[
      true,
      true,
      true,
    ]);
    expect(plan.clips.map((PlannedClip c) => c.bodyFrames), <int>[50, 25, 20]);
    expect(plan.clips.map((PlannedClip c) => c.tailFrames), <int>[10, 10, 0]);
    expect(plan.chapterDurationsMs, <int>[1733, 1233, 1000]);
    expect(plan.totalMs, 3966);
  });

  // The same three clips at 60 fps: twice the frames, the same times; each clip but the
  // last loses the 16 overlapped frames.
  test('at 60 fps the cuts are at the 60 fps keyframes and the overlap is '
      '16 frames, so the lengths in ms are the same as at 30', () {
    final TransitionPlan plan = TransitionPlan.of(
      <({int? durationMs, ClipKeyframes? keyframes})>[
        saved60(120),
        saved60(90),
        saved60(60),
      ],
      fps: _f60,
    );
    expect(plan.clips.map((PlannedClip c) => c.headCut), <int>[0, 20, 20]);
    expect(plan.clips.map((PlannedClip c) => c.tailCut), <int?>[100, 70, null]);
    expect(plan.clips.map((PlannedClip c) => c.bodyFrames), <int>[100, 50, 40]);
    expect(plan.clips.map((PlannedClip c) => c.tailFrames), <int>[20, 20, 0]);
    expect(plan.chapterDurationsMs, <int>[1733, 1233, 1000]);
    expect(plan.totalMs, 3966);
    // A clip with one keyframe cannot be cut at 60 either.
    final TransitionPlan mixed = TransitionPlan.of(
      <({int? durationMs, ClipKeyframes? keyframes})>[older(60), saved60(90)],
      fps: _f60,
    );
    expect(mixed.transitions, <bool>[false]);
  });

  // An older clip in the middle takes hard cuts on both sides: the clip
  // before it keeps its end, the clip after keeps its start, and the older
  // clip itself needs no body file. A clip whose keyframes could not be
  // read is treated the same.
  test('an older or unreadable clip gives hard cuts on both sides and joins '
      'as it is', () {
    final TransitionPlan plan =
        TransitionPlan.of(<({int? durationMs, ClipKeyframes? keyframes})>[
          saved(60),
          older(45),
          saved(45),
          (durationMs: 1500, keyframes: null),
          saved(30),
        ], fps: _f30);
    expect(plan.transitions, <bool>[false, false, false, false]);
    expect(plan.hardCuts, 4);
    expect(plan.transitionCount, 0);
    expect(
      plan.clips.map((PlannedClip c) => c.needsBody),
      everyElement(isFalse),
    );
    expect(plan.chapterDurationsMs, <int>[2000, 1500, 1500, 1500, 1000]);
  });

  test('a mix: transitions only where both sides can be cut', () {
    final TransitionPlan plan = TransitionPlan.of(
      <({int? durationMs, ClipKeyframes? keyframes})>[
        saved(45),
        saved(45),
        older(45),
        saved(45),
      ],
      fps: _f30,
    );
    expect(plan.transitions, <bool>[true, false, false]);
    expect(plan.clips[1].headCut, 10);
    expect(plan.clips[1].tailCut, isNull);
    expect(plan.clips[1].needsBody, isTrue);
    expect(plan.clips[3].headCut, 0);
    expect(plan.clips[3].needsBody, isFalse);
    expect(plan.chapterDurationsMs, <int>[1233, 1500, 1500, 1500]);
  });

  // A 1 s clip between two others: head 10, tail 20, a 10-frame body.
  test('a one-second clip is cut to a 10-frame body', () {
    final TransitionPlan plan = TransitionPlan.of(
      <({int? durationMs, ClipKeyframes? keyframes})>[
        saved(45),
        saved(30),
        saved(45),
      ],
      fps: _f30,
    );
    expect(plan.clips[1].headCut, 10);
    expect(plan.clips[1].tailCut, 20);
    expect(plan.clips[1].bodyFrames, 10);
    expect(plan.transitions, <bool>[true, true]);
  });

  test('two clips: one boundary', () {
    final TransitionPlan plan = TransitionPlan.of(
      <({int? durationMs, ClipKeyframes? keyframes})>[saved(45), saved(45)],
      fps: _f30,
    );
    expect(plan.transitions, <bool>[true]);
    expect(plan.clips.first.tailCut, 35);
    expect(plan.clips.last.headCut, 10);
    expect(plan.clips.last.tailCut, isNull);
  });
}
