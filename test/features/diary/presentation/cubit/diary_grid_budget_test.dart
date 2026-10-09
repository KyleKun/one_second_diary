// Perf guard: what the calendar reads to draw a month (the 42 cells, "N of
// M days", the Make movie chip) costs the same whatever the diary's size.
//
// As in `clip_index_query_budget_test.dart`, one absolute budget can't
// tell O(1) from O(N) on a fast machine, so the SAME work runs over a
// diary of 500 and of 5 000 clips and the growth is asserted; the absolute
// budget is a backstop.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_day.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../support/diary_fixtures.dart';

const int _smallClips = 500;
const int _clips = 5000;

/// Month grids drawn per measurement: a few milliseconds on the small
/// diary, so timer noise stays well below the ratio asserted.
const int _grids = 2000;
const int _rounds = 5;

/// time(5 000) / time(500) above which the grid is O(N): a hash lookup
/// grows not at all, a binary search about 1.4×, a scan 10×.
const double _maxGrowth = 3;

/// Generous for a debug-mode `flutter test` on a loaded machine.
const Duration _budget = Duration(milliseconds: 400);

final LocalDay _today = LocalDay(2026, 9, 28);

DiaryState _diaryOf(int clips) => DiaryState(
  profile: const Profile(
    key: ProfileKey.defaultProfile,
    displayName: 'Default',
    orientation: VideoOrientation.landscape,
    avatarRelPath: null,
  ),
  index: diaryIndex(ProfileKey.defaultProfile, <LocalDay, int>{
    for (int i = 0; i < clips; i++) _today.addDays(-i): 1,
  }),
  today: _today,
  month: DiaryMonth.of(_today),
  selected: _today,
);

/// Draws [_grids] month grids' worth of data, walking back one month per
/// grid so every part of the diary is read; returns the fastest round.
Duration _timeGrids(DiaryState diary) {
  Duration best = const Duration(days: 1);
  int sink = 0;
  for (int round = 0; round <= _rounds; round++) {
    DiaryMonth month = diary.month;
    final Stopwatch watch = Stopwatch()..start();
    for (int grid = 0; grid < _grids; grid++) {
      final DiaryState shown = diary.showing(month, selected: month.first);
      for (int day = 1; day <= month.dayCount; day++) {
        final DiaryDay cell = shown.dayOf(
          LocalDay(month.year, month.month, day),
        );
        sink += cell.clipCount;
      }
      sink += shown.monthCount!.recorded;
      month = month.previous;
      if (month.isBefore(DiaryState.historyStart)) month = diary.month;
    }
    watch.stop();
    // The first round warms the JIT up.
    if (round > 0 && watch.elapsed < best) best = watch.elapsed;
  }
  expect(sink, isNonNegative);
  return best;
}

void main() {
  test('a month grid costs the same over 500 and 5 000 clips', () {
    final Duration small = _timeGrids(_diaryOf(_smallClips));
    final Duration large = _timeGrids(_diaryOf(_clips));

    final double growth = large.inMicroseconds / small.inMicroseconds;
    expect(
      growth,
      lessThan(_maxGrowth),
      reason:
          '$_grids grids took $small over $_smallClips clips and $large '
          'over $_clips: a cell or a count scans the clips',
    );
    expect(large, lessThan(_budget));
  });
}
