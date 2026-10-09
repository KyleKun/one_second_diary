import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clip_editor/domain/quick_cuts.dart';

/// The part of a video source a clip keeps: the trim window, in ms.
final class TrimSelection extends Equatable {
  const TrimSelection._({
    required this.sourceMs,
    required this.startMs,
    required this.lengthMs,
  });

  /// The window a source opens with: its first [lengthMs] (kept within [minLengthMs]..[maxLengthMs]), or the whole source when shorter.
  /// The length comes from the camera's setting for an in-app recording, the last quick cut for an import.
  factory TrimSelection.initial({
    required int sourceMs,
    int lengthMs = maxLengthMs,
  }) => TrimSelection._(
    sourceMs: sourceMs,
    startMs: 0,
    lengthMs: math.min(sourceMs, lengthMs.clamp(minLengthMs, maxLengthMs)),
  );

  /// The longest clip: 60 s, the camera's longest too.
  static const int maxLengthMs = 60000;

  static const int minLengthMs = 1000;

  /// A source this long or shorter is kept whole.
  static const int lockedUpToMs = 1500;

  /// The source's duration.
  final int sourceMs;

  final int startMs;

  final int lengthMs;

  int get endMs => startMs + lengthMs;

  /// The window of a source of [lockedUpToMs] or less is the whole source:
  /// it neither moves nor changes length.
  bool get locked => sourceMs <= lockedUpToMs;

  /// Whether a quick cut of [lengthMs] fits the source, compared to the ms.
  bool allows(int lengthMs) => !locked && lengthMs <= sourceMs;

  /// The window moved to start at [startMs], its length kept, within the
  /// source.
  TrimSelection movedTo(int startMs) => locked
      ? this
      : TrimSelection._(
          sourceMs: sourceMs,
          startMs: startMs.clamp(0, sourceMs - lengthMs),
          lengthMs: lengthMs,
        );

  /// The shortest window: [minLengthMs], or the whole source when shorter.
  int get shortestMs => math.min(minLengthMs, sourceMs);

  /// The longest window: [maxLengthMs], or the whole source when shorter.
  int get longestMs => math.min(maxLengthMs, sourceMs);

  /// Where the saved clip ends: exactly the window's end, never past the source.
  int get savedEndMs => math.min(endMs, sourceMs);

  /// How long the saved clip is (what the readout shows).
  int get savedLengthMs => savedEndMs - startMs;

  /// The quick cut this window's length is, if any.
  int? get quickCutMs =>
      QuickCuts.lengthsMs.contains(lengthMs) ? lengthMs : null;

  /// The end edge dragged to [endMs]: the start stays, the length stays
  /// between [shortestMs] and [longestMs] and snaps to a quick cut within
  /// `QuickCuts.snapMs`, and the end stays within the source.
  TrimSelection withEndAt(int endMs) {
    if (locked) return this;
    final int length = _fitted(endMs - startMs, room: sourceMs - startMs);
    return TrimSelection._(
      sourceMs: sourceMs,
      startMs: startMs,
      lengthMs: length,
    );
  }

  /// The start edge dragged to [startMs]: the end stays, the length stays
  /// between [shortestMs] and [longestMs] and snaps to a quick cut within
  /// `QuickCuts.snapMs`, and the start stays within the source.
  TrimSelection withStartAt(int startMs) {
    if (locked) return this;
    final int end = endMs;
    final int length = _fitted(end - startMs, room: end);
    return TrimSelection._(
      sourceMs: sourceMs,
      startMs: end - length,
      lengthMs: length,
    );
  }

  /// [lengthMs] snapped to a quick cut when close to one, then kept between
  /// [shortestMs] and [longestMs], and within the [room] the edge has.
  int _fitted(int lengthMs, {required int room}) {
    final int snapped = QuickCuts.snapOf(lengthMs) ?? lengthMs;
    return snapped.clamp(shortestMs, math.min(longestMs, room));
  }

  /// A quick cut: the window [lengthMs] long (kept between [shortestMs] and
  /// [longestMs]) from the current start, moved back as far as it must to
  /// end within the source.
  TrimSelection withLength(int lengthMs) {
    if (locked) return this;
    final int length = lengthMs.clamp(shortestMs, longestMs);
    return TrimSelection._(
      sourceMs: sourceMs,
      startMs: math.min(startMs, sourceMs - length),
      lengthMs: length,
    );
  }

  /// A window from [startMs] to [endMs] fitted to this source, for a
  /// recipe made for it earlier (`ClipRecipe`): the start stays within the
  /// source, the end within it too, and the length within the rules. A
  /// start at or past the source's end is dropped: the window opens as
  /// it would without a recipe.
  TrimSelection fitted({required int startMs, required int endMs}) {
    if (locked || startMs < 0 || startMs >= sourceMs || endMs <= startMs) {
      return this;
    }
    return movedTo(startMs).withEndAt(endMs);
  }

  @override
  List<Object?> get props => <Object?>[sourceMs, startMs, lengthMs];
}
