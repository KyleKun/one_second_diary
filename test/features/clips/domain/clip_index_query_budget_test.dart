// Perf guard: every ClipIndex query a screen makes per cell, per tap or per
// frame is O(1) or O(log n).
//
// A single absolute budget cannot tell O(log n) from O(N) on a fast machine.
// So each query family runs the SAME number of queries over a small and a
// large index of the same shape and asserts how the time grows: 10× the
// clips costs about 1.4× for a binary search, 1× for a hash lookup and 10×
// for a scan. The absolute budget stays as a backstop.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

const int _clips = 5000;
const int _smallClips = 500;

/// Queries per family and measurement: enough for a few milliseconds on the
/// small index, so timer noise stays well below the ratio being asserted.
const int _queries = 20000;

/// Best of this many timed runs per index, after a warm-up run.
const int _rounds = 5;

/// time(5 000 clips) / time(500 clips) above which a family is O(N). A
/// binary search grows about 1.4×, a hash lookup not at all, a scan 10×.
const int _maxGrowth = 3;

/// Generous for a debug-mode `flutter test` on a slow CI runner; the
/// queries take a few milliseconds on a laptop.
const Duration _budget = Duration(milliseconds: 250);

ClipIndex _indexOf(int count) {
  final LocalDay first = LocalDay(2012, 1, 1);
  final List<IndexedClip> clips = <IndexedClip>[];
  for (int i = 0; clips.length < count; i++) {
    if (i % 9 == 4) continue; // a missed day now and then
    final LocalDay day = first.addDays(i);
    // Every fifth recorded day has a second clip.
    for (int ordinal = 1; ordinal <= (i % 5 == 0 ? 2 : 1); ordinal++) {
      clips.add(
        IndexedClip(
          ref: ClipRef(
            profile: ProfileKey.defaultProfile,
            relPath: ClipNameCodec.format(day, ordinal: ordinal),
          ),
          stamp: const FileStamp(sizeBytes: 8, modifiedMs: 0),
        ),
      );
    }
  }
  return ClipIndex(profile: ProfileKey.defaultProfile, clips: clips);
}

/// One index and the arguments of [_queries] queries spread evenly over
/// its span, built before any timing so only the queries are measured.
final class _Workload {
  _Workload(this.index)
    : days = <LocalDay>[
        for (int q = 0; q < _queries; q++)
          index.firstDay!.addDays(q * _spanOf(index) ~/ _queries),
      ],
      ranges = <DayRange>[
        for (int q = 0; q < _queries; q++)
          DayRange(
            first: index.firstDay!.addDays(q * _spanOf(index) ~/ _queries),
            last: index.lastDay!,
          ),
      ],
      clips = _sample(index.newestFirst.toList());

  final ClipIndex index;
  final List<LocalDay> days;
  final List<DayRange> ranges;
  final List<ClipRef> clips;

  static int _spanOf(ClipIndex index) =>
      index.lastDay!.epochDay - index.firstDay!.epochDay + 1;

  static List<ClipRef> _sample(List<ClipRef> all) => <ClipRef>[
    for (int q = 0; q < _queries; q++) all[q * all.length ~/ _queries],
  ];
}

/// How much longer [family] takes over [_clips] clips than over
/// [_smallClips], best of [_rounds] each.
double _growthOf(int Function(_Workload workload) family) {
  final _Workload small = _Workload(_indexOf(_smallClips));
  final _Workload large = _Workload(_indexOf(_clips));
  int sink = family(small) + family(large); // warm-up (JIT)
  int bestSmall = 1 << 62;
  int bestLarge = 1 << 62;
  for (int round = 0; round < _rounds; round++) {
    final Stopwatch watch = Stopwatch()..start();
    sink += family(small);
    bestSmall = math.min(bestSmall, watch.elapsedMicroseconds);
    watch.reset();
    sink += family(large);
    bestLarge = math.min(bestLarge, watch.elapsedMicroseconds);
  }
  expect(sink, greaterThan(0));
  return bestLarge / math.max(bestSmall, 1);
}

/// Diary cells: has the day a clip, and which (the badge and first clip).
int _cells(_Workload w) {
  int sink = 0;
  for (final LocalDay day in w.days) {
    if (w.index.hasDay(day)) sink += w.index.clipsOn(day).length;
  }
  return sink;
}

/// Viewer chevrons and player warm-up.
int _neighbours(_Workload w) {
  int sink = 0;
  for (final ClipRef clip in w.clips) {
    if (w.index.previousClip(clip) != null) sink++;
    if (w.index.nextClip(clip) != null) sink++;
  }
  return sink;
}

/// Live "N clips found", "N of M days" and month summaries.
int _counts(_Workload w) {
  int sink = 0;
  for (final DayRange range in w.ranges) {
    sink += w.index.countClipsIn(range);
  }
  for (final LocalDay day in w.days) {
    sink += w.index
        .monthSummary(year: day.year, month: day.month, today: w.index.lastDay!)
        .recorded;
  }
  return sink;
}

void main() {
  test('Diary cells, neighbours and counts: 10× the clips costs less than '
      '$_maxGrowth× the time (O(1) or O(log n), never O(N))', () {
    for (final (String family, int Function(_Workload) queries)
        in <(String, int Function(_Workload))>[
          ('Diary cells (hasDay, clipsOn)', _cells),
          ('neighbours (previousClip, nextClip)', _neighbours),
          ('counts (countClipsIn, monthSummary)', _counts),
        ]) {
      expect(
        _growthOf(queries),
        lessThan(_maxGrowth),
        reason: 'a $family query became O(N)',
      );
    }
  });

  test('backstop: month grids, neighbours and range counts over $_clips '
      'clips stay within ${_budget.inMilliseconds} ms', () {
    final ClipIndex index = _indexOf(_clips);
    final LocalDay today = index.lastDay!;
    final List<ClipRef> all = index.newestFirst.toList();
    expect(index.clipCount, _clips);

    final Stopwatch watch = Stopwatch()..start();
    int sink = 0;
    // Every month grid of the diary (42 cells each), as the Diary builds it.
    for (int year = 2012; year <= today.year; year++) {
      for (int month = 1; month <= 12; month++) {
        final LocalDay firstOfMonth = LocalDay(year, month, 1);
        for (int cell = -6; cell < 36; cell++) {
          final LocalDay day = firstOfMonth.addDays(cell);
          if (index.hasDay(day)) sink += index.clipsOn(day).length;
        }
        sink += index
            .monthSummary(year: year, month: month, today: today)
            .recorded;
      }
      sink += index.clipsPerMonth(year)[0];
    }
    // Previous / next of every clip (viewer chevrons, player warm-up).
    for (final ClipRef clip in all) {
      if (index.previousClip(clip) != null) sink++;
      if (index.nextClip(clip) != null) sink++;
    }
    // Live "N clips found" for every possible start day.
    for (int i = 0; i < _clips; i++) {
      sink += index.countClipsIn(
        DayRange(first: today.addDays(-i), last: today),
      );
    }
    watch.stop();

    expect(sink, greaterThan(0));
    expect(
      watch.elapsed,
      lessThan(_budget),
      reason: 'a ClipIndex query became O(N)',
    );
  });
}
