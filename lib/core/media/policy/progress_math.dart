/// Progress of a running ffmpeg job, from its statistics' output time. Every
/// formula divides by the exact length in ms, never by whole seconds.
abstract final class ProgressMath {
  /// The highest fraction reported before the job completes, so the bar
  /// never reads "done" while the session still runs.
  static const double maxFraction = 0.999;

  /// The fraction done of a job expected to produce [expectedMs] of output
  /// after [processedMs]; null (no update) before any output or when the
  /// expected length is not positive.
  static double? fraction({required int processedMs, required int expectedMs}) {
    if (processedMs <= 0 || expectedMs <= 0) return null;
    final double ratio = processedMs / expectedMs;
    return ratio >= 1 ? maxFraction : ratio;
  }

  /// A video save: the output is the trim, [trimStartMs] to [trimEndMs].
  static double? saveVideo({
    required int timeMs,
    required int trimStartMs,
    required int trimEndMs,
  }) => fraction(processedMs: timeMs, expectedMs: trimEndMs - trimStartMs);

  /// A photo save: the output lasts [durationSeconds] (`-t`).
  static double? savePhoto({
    required int timeMs,
    required double durationSeconds,
  }) => fraction(
    processedMs: timeMs,
    expectedMs: (durationSeconds * 1000).round(),
  );

  /// The work of a movie with transitions, in units: a body
  /// cut is 1 (a stream copy), a rendered segment 4 (a decode and an
  /// encode of a few frames), an audio pass 2, and the final concat one
  /// unit per 10 clips, at least 1 (a stream copy of the whole movie).
  static const int bodyUnits = 1;
  static const int segmentUnits = 4;
  static const int audioPassUnits = 2;

  /// A movie's music: the tracks joined (a decode), the loop
  /// (a copy) and the mix (an encode of the whole length).
  static const int musicSequenceUnits = 1;
  static const int musicLoopUnits = 1;
  static const int musicMixUnits = 2;
  static const int musicUnits =
      musicSequenceUnits + musicLoopUnits + musicMixUnits;

  /// The concat's units for a movie of [clips] clips.
  static int concatUnitsFor(int clips) => clips < 10 ? 1 : clips ~/ 10;

  /// A movie with transitions: [unitsDone] of [totalUnits] (the concat's
  /// units count as its own fraction, 0 to 1, times its units, so the bar
  /// keeps moving during it). 0 before any work, never above
  /// [maxFraction] before the end.
  static double transitionMovie({
    required double unitsDone,
    required int totalUnits,
  }) {
    if (totalUnits <= 0 || unitsDone <= 0) return 0;
    final double ratio = unitsDone / totalUnits;
    return ratio >= maxFraction ? maxFraction : ratio;
  }

  /// The movie concat: [timeMs] over the sum of [clipDurationsMs] (in movie
  /// order), and the clip being copied, the first whose end is past
  /// [timeMs] (the last one once the time runs past the total). Always a
  /// value, so the screen moves from 0.
  static ({double fraction, int currentIndex}) movie({
    required int timeMs,
    required List<int> clipDurationsMs,
  }) {
    int total = 0;
    int? currentIndex;
    for (final (int index, int duration) in clipDurationsMs.indexed) {
      total += duration;
      if (currentIndex == null && total > timeMs) currentIndex = index;
    }
    return (
      fraction: fraction(processedMs: timeMs, expectedMs: total) ?? 0,
      currentIndex:
          currentIndex ??
          (clipDurationsMs.isEmpty ? 0 : clipDurationsMs.length - 1),
    );
  }
}
