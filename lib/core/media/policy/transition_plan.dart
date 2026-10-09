import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/policy/transition_policy.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';

/// One clip of a movie with transitions, as the plan cuts it, at the
/// movie format's frame rate [fps].
final class PlannedClip extends Equatable {
  const PlannedClip({
    required this.durationMs,
    required this.frameCount,
    required this.headCut,
    required this.tailCut,
    required this.transitionAfter,
    required this.fps,
  });

  /// The clip's container length, as the request knew it.
  final int? durationMs;

  /// Its video frames; null when its keyframes could not be read (it then
  /// joins as it is, with hard cuts).
  final int? frameCount;

  /// The keyframe its body starts at: 0 for the clip's start (no
  /// transition before it).
  final int headCut;

  /// The keyframe its body ends before; null for the clip's end (no
  /// transition after it).
  final int? tailCut;

  /// Whether the boundary after this clip is a transition.
  final bool transitionAfter;

  /// The movie format's frame rate, which every frame count here is at.
  final FrameRate fps;

  /// Whether a body file is cut for it; a clip uncut on both sides joins
  /// as it is, exactly as in a movie without transitions.
  bool get needsBody => headCut > 0 || tailCut != null;

  /// The frames of its body, or of the whole clip; null while unknown.
  int? get bodyFrames => switch ((frameCount, tailCut)) {
    (_, final int tail) => tail - headCut,
    (final int frames, null) => frames - headCut,
    (null, null) => null,
  };

  /// The frames of its tail (the ones rendered into the transition after
  /// it); 0 without one.
  int get tailFrames =>
      tailCut == null || frameCount == null ? 0 : frameCount! - tailCut!;

  /// The frames it takes in the movie: all of them, less the transition
  /// after it, which overlaps the next clip.
  int? get plannedFrames => frameCount == null
      ? null
      : frameCount! - (transitionAfter ? TransitionPolicy.frames(fps) : 0);

  /// Its length in the movie, in whole milliseconds, from its frames when
  /// known, else its container length.
  int get plannedMs => switch (plannedFrames) {
    final int frames => (frames * 1000 / fps.value).round(),
    null => durationMs ?? 0,
  };

  @override
  List<Object?> get props => <Object?>[
    durationMs,
    frameCount,
    headCut,
    tailCut,
    transitionAfter,
    fps,
  ];
}

/// Which boundaries of a movie get the transition and where each clip is
/// cut for it, decided from the clips' keyframes alone.
///
/// Left to right: the boundary between clip A and clip B is a transition
/// when A has a keyframe at least `TransitionPolicy.frames` before its end
/// (after A's own head cut) and B one at least that far from its start
/// (`TransitionPolicy.tailCut` / `headCut`). Otherwise it is a hard cut,
/// and A's end and B's start stay uncut. The first clip's start and the
/// last clip's end are never cut. A clip whose keyframes are unknown takes
/// hard cuts on both sides.
final class TransitionPlan extends Equatable {
  const TransitionPlan._(this.clips, this.fps);

  /// The plan of [clips], in movie order, at the movie format's [fps].
  factory TransitionPlan.of(
    List<({int? durationMs, ClipKeyframes? keyframes})> clips, {
    required FrameRate fps,
  }) {
    final List<PlannedClip> planned = <PlannedClip>[];
    int head = 0;
    for (final (int index, (:int? durationMs, :ClipKeyframes? keyframes))
        in clips.indexed) {
      int? tail;
      int nextHead = 0;
      if (index < clips.length - 1 && keyframes != null) {
        final ClipKeyframes? next = clips[index + 1].keyframes;
        final int? tailCandidate = TransitionPolicy.tailCut(
          keyframes,
          headCut: head,
          fps: fps,
        );
        final int? headCandidate = next == null
            ? null
            : TransitionPolicy.headCut(next, fps: fps);
        if (tailCandidate != null && headCandidate != null) {
          tail = tailCandidate;
          nextHead = headCandidate;
        }
      }
      planned.add(
        PlannedClip(
          durationMs: durationMs,
          frameCount: keyframes?.frameCount,
          headCut: head,
          tailCut: tail,
          transitionAfter: tail != null,
          fps: fps,
        ),
      );
      head = nextHead;
    }
    return TransitionPlan._(List<PlannedClip>.unmodifiable(planned), fps);
  }

  final List<PlannedClip> clips;

  /// The movie format's frame rate.
  final FrameRate fps;

  /// Whether boundary [index] (after clip [index]) is a transition.
  bool isTransition(int index) => clips[index].transitionAfter;

  /// One entry per boundary: the transitions.
  List<bool> get transitions => List<bool>.unmodifiable(<bool>[
    for (int index = 0; index < clips.length - 1; index++)
      clips[index].transitionAfter,
  ]);

  int get transitionCount =>
      clips.where((PlannedClip clip) => clip.transitionAfter).length;

  int get hardCuts => clips.length - 1 - transitionCount;

  /// Each clip's length in the movie, in ms, for its chapter: a chapter
  /// ends where the next clip's first frame appears, at the fade's start.
  List<int> get chapterDurationsMs => List<int>.unmodifiable(<int>[
    for (final PlannedClip clip in clips) clip.plannedMs,
  ]);

  /// The movie's length in ms.
  int get totalMs => chapterDurationsMs.fold(0, (int sum, int ms) => sum + ms);

  @override
  List<Object?> get props => <Object?>[clips, fps];
}
