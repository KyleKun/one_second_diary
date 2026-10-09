import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/progress_math.dart';

void main() {
  // Divided by whole seconds, a 1.5 s clip would read 75 % at half-way and
  // 99.9 % at 1 s, and a trim under 1 s would give no progress at all.
  // Capped at 99.9 %: the bar never reads "done" before the session has
  // ended. No divide by zero and no sample before any output.
  test('ProgressMath.saveVideo: output time over the exact trim length', () {
    const List<(int, int, int, double?)> cases = <(int, int, int, double?)>[
      // (time, trim start, trim end, fraction)
      (750, 0, 1500, 0.5),
      (1000, 0, 1500, 2 / 3),
      (1750, 0, 3500, 0.5),
      (500, 100, 1000, 5 / 9),
      (1500, 0, 1500, 0.999),
      (5000, 0, 1000, 0.999),
      (0, 0, 1500, null),
      (400, 900, 900, null),
    ];
    for (final (int time, int start, int end, double? fraction) in cases) {
      final double? actual = ProgressMath.saveVideo(
        timeMs: time,
        trimStartMs: start,
        trimEndMs: end,
      );
      expect(
        actual,
        fraction == null ? isNull : closeTo(fraction, 1e-9),
        reason: '$time ms of $start..$end',
      );
    }
  });

  // The percentages for the samples [times]; null is no update.
  test('ProgressMath.savePhoto: time over the photo duration, as in v1.7', () {
    const List<int> times = <int>[0, 1, 250, 750, 1000, 1500, 12000];
    const List<(double, List<double?>)> v17 = <(double, List<double?>)>[
      (1, <double?>[null, 0.1, 25, 75, 99.9, 99.9, 99.9]),
      (
        1.5,
        <double?>[
          null,
          0.06666666666666667,
          16.666666666666664,
          50,
          66.66666666666666,
          99.9,
          99.9,
        ],
      ),
      (2, <double?>[null, 0.05, 12.5, 37.5, 50, 75, 99.9]),
      (
        3,
        <double?>[
          null,
          0.03333333333333333,
          8.333333333333332,
          25,
          33.33333333333333,
          50,
          99.9,
        ],
      ),
      (5, <double?>[null, 0.02, 5, 15, 20, 30, 99.9]),
      (10, <double?>[null, 0.01, 2.5, 7.5, 10, 15, 99.9]),
    ];
    for (final (double seconds, List<double?> percents) in v17) {
      for (final (int i, int timeMs) in times.indexed) {
        final double? fraction = ProgressMath.savePhoto(
          timeMs: timeMs,
          durationSeconds: seconds,
        );
        final double? percent = percents[i];
        if (percent == null) {
          expect(fraction, isNull, reason: '$seconds s at $timeMs ms');
        } else {
          expect(
            fraction! * 100,
            closeTo(percent, 1e-9),
            reason: '$seconds s at $timeMs ms',
          );
        }
      }
    }
  });

  // The fraction of the summed clip durations, from 0 and below 1 until
  // completed; the current clip is the first whose end is past the time; an
  // unknown total reads 0 on the first clip.
  test('ProgressMath.movie: over the summed durations, with the clip being '
      'copied', () {
    const List<int> durations = <int>[1500, 1500, 2000];
    const List<(int, List<int>, double, int)> cases =
        <(int, List<int>, double, int)>[
          // (time, durations, fraction, current clip)
          (0, durations, 0, 0),
          (1499, durations, 1499 / 5000, 0),
          (1500, durations, 0.3, 1),
          (1600, durations, 0.32, 1),
          (2999, durations, 2999 / 5000, 1),
          (3000, durations, 0.6, 2),
          (5000, durations, ProgressMath.maxFraction, 2),
          (9000, durations, ProgressMath.maxFraction, 2),
          (800, <int>[], 0, 0),
        ];
    for (final (int time, List<int> clips, double fraction, int index)
        in cases) {
      final ({double fraction, int currentIndex}) progress = ProgressMath.movie(
        timeMs: time,
        clipDurationsMs: clips,
      );
      expect(
        progress.fraction,
        closeTo(fraction, 1e-9),
        reason: '$time ms of $clips',
      );
      expect(progress.currentIndex, index, reason: '$time ms of $clips');
    }
  });

  // A movie with transitions counts its work in units; the concat's units grow with the
  // clips, and the bar never reads done.
  test('ProgressMath.transitionMovie: units done over the total, 0 before '
      'any, capped below 1; the concat weighs one unit per 10 clips', () {
    expect(ProgressMath.transitionMovie(unitsDone: 0, totalUnits: 12), 0);
    expect(ProgressMath.transitionMovie(unitsDone: 3, totalUnits: 12), 0.25);
    expect(
      ProgressMath.transitionMovie(unitsDone: 11.5, totalUnits: 12),
      closeTo(11.5 / 12, 1e-9),
    );
    expect(
      ProgressMath.transitionMovie(unitsDone: 12, totalUnits: 12),
      ProgressMath.maxFraction,
    );
    expect(ProgressMath.transitionMovie(unitsDone: 5, totalUnits: 0), 0);
    expect(ProgressMath.concatUnitsFor(2), 1);
    expect(ProgressMath.concatUnitsFor(9), 1);
    expect(ProgressMath.concatUnitsFor(10), 1);
    expect(ProgressMath.concatUnitsFor(365), 36);
    // The music's three steps.
    expect(
      ProgressMath.musicUnits,
      ProgressMath.musicSequenceUnits +
          ProgressMath.musicLoopUnits +
          ProgressMath.musicMixUnits,
    );
  });
}
