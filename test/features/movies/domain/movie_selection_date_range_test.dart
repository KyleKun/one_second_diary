// "Choose dates": a movie of exactly the days picked, in play order, never
// past today, and the same number of days across a DST change.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/movies/domain/movie_selection.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

LocalDay d(int y, int m, int day) => LocalDay(y, m, day);

ClipIndex _index(Iterable<String> relPaths) => ClipIndex(
  profile: ProfileKey.defaultProfile,
  clips: <IndexedClip>[
    for (final String relPath in relPaths)
      IndexedClip(
        ref: ClipRef(profile: ProfileKey.defaultProfile, relPath: relPath),
        stamp: const FileStamp(sizeBytes: 8, modifiedMs: 0),
      ),
  ],
);

/// One clip a day from [first] through [last].
ClipIndex _daily(LocalDay first, LocalDay last) => _index(<String>[
  for (LocalDay day = first; !day.isAfter(last); day = day.addDays(1))
    '${day.fileStem}.mp4',
]);

List<String> _paths(List<ClipRef> clips) => <String>[
  for (final ClipRef clip in clips) clip.relPath,
];

void main() {
  final LocalDay today = d(2026, 9, 28);

  test('the days picked play every clip of each day, by day then ordinal, '
      'with its real path; nothing outside them', () {
    final ClipIndex index = _index(<String>[
      '2026-09-02.mp4',
      '2026-09-03-2.mp4',
      'Trip/2026-09-03.mp4',
      '2026-09-05.mp4',
      '2026-09-12.mp4',
      '2026-09-13.mp4',
    ]);
    final MovieSource source = MovieSource.dateRange(
      DayRange(first: d(2026, 9, 3), last: d(2026, 9, 12)),
    );

    expect(_paths(index.clipsFor(source, today: today)), <String>[
      'Trip/2026-09-03.mp4',
      '2026-09-03-2.mp4',
      '2026-09-05.mp4',
      '2026-09-12.mp4',
    ]);
    expect(index.countClipsFor(source, today: today), 4);
    expect(
      index.rangeOf(source, today: today),
      DayRange(first: d(2026, 9, 3), last: d(2026, 9, 12)),
    );
  });

  test('a range ending after today ends today (a wrong clock never adds '
      'future days, or reports them skipped)', () {
    final ClipIndex index = _daily(d(2026, 9, 20), d(2026, 9, 30));
    final MovieSource source = MovieSource.dateRange(
      DayRange(first: d(2026, 9, 25), last: d(2026, 10, 2)),
    );

    expect(
      index.rangeOf(source, today: today),
      DayRange(first: d(2026, 9, 25), last: today),
    );
    expect(_paths(index.clipsFor(source, today: today)), <String>[
      '2026-09-25.mp4',
      '2026-09-26.mp4',
      '2026-09-27.mp4',
      '2026-09-28.mp4',
    ]);
    expect(index.countClipsFor(source, today: today), 4);
  });

  test('a range across a spring-forward keeps its day count in any time '
      'zone (Europe on 2026-03-29, Chile on 2026-09-06)', () {
    final ClipIndex index = _daily(d(2026, 1, 1), d(2026, 12, 31));
    final List<(LocalDay, LocalDay)> ranges = <(LocalDay, LocalDay)>[
      (d(2026, 3, 27), d(2026, 4, 2)),
      (d(2026, 9, 3), d(2026, 9, 9)),
    ];
    for (final (LocalDay first, LocalDay last) in ranges) {
      final MovieSource source = MovieSource.dateRange(
        DayRange(first: first, last: last),
      );
      final List<ClipRef> clips = index.clipsFor(
        source,
        today: d(2026, 12, 31),
      );
      expect(clips, hasLength(7), reason: '$first..$last');
      expect(clips.first.day, first);
      expect(clips.last.day, last);
    }
  });
}
