// What the confirmation shows about the movie asked for, from the index
// alone: its clips in play order, the days of its range without a clip, its
// clips' size and the 16 mosaic cells.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/movies/domain/movie_draft.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

final LocalDay _today = LocalDay(2026, 9, 28);

ClipRef _clip(String relPath) =>
    ClipRef(profile: ProfileKey.defaultProfile, relPath: relPath);

/// One clip of [bytes] on each of [days] of September 2026.
ClipIndex _september(Iterable<int> days, {int bytes = 1000}) => ClipIndex(
  profile: ProfileKey.defaultProfile,
  clips: <IndexedClip>[
    for (final int day in days)
      IndexedClip(
        ref: _clip('${LocalDay(2026, 9, day).fileStem}.mp4'),
        stamp: FileStamp(sizeBytes: bytes, modifiedMs: 0),
      ),
  ],
);

void main() {
  // September with days 9, 21 and 25 missing.
  test('a month: its clips, the days without one, their size; picked clips: '
      'in play order, no range, nothing skipped; too few clips cannot make a '
      'movie', () {
    final MovieDraft month = MovieDraft.of(
      _september(<int>[
        for (int day = 1; day <= 28; day++)
          if (day != 9 && day != 21 && day != 25) day,
      ]),
      const MovieSource.month(year: 2026, month: 9),
      today: _today,
    );
    expect(month.clips, hasLength(25));
    expect(month.clips.first.day, LocalDay(2026, 9, 1));
    expect(
      month.range,
      DayRange(first: LocalDay(2026, 9, 1), last: _today),
      reason: 'never after today',
    );
    expect(month.skippedDays, <LocalDay>[
      LocalDay(2026, 9, 9),
      LocalDay(2026, 9, 21),
      LocalDay(2026, 9, 25),
    ]);
    expect(month.clipBytes, 25 * 1000);
    expect(month.canMake, isTrue);

    final MovieDraft picked = MovieDraft.of(
      _september(<int>[1, 2, 3, 4]),
      MovieSource.custom(<ClipRef>{
        _clip('2026-09-04.mp4'),
        _clip('2026-09-02.mp4'),
      }),
      today: _today,
    );
    expect(picked.clips, <ClipRef>[
      _clip('2026-09-02.mp4'),
      _clip('2026-09-04.mp4'),
    ]);
    expect(picked.range, isNull);
    expect(picked.skippedDays, isEmpty);

    final MovieDraft tooFew = MovieDraft.of(
      _september(<int>[28]),
      const MovieSource.preset(MoviePreset.last7Days),
      today: _today,
    );
    expect(tooFew.clips, hasLength(1));
    expect(tooFew.canMake, isFalse);
    expect(tooFew.skippedDays, hasLength(6));
  });

  test('the mosaic samples 16 clips evenly from the first to the last; fewer '
      'repeat in order to fill the 16 cells; no clips, no cells', () {
    List<int> mosaicOf(Iterable<int> days) => <int>[
      for (final ClipRef cell in MovieDraft.of(
        _september(days),
        const MovieSource.month(year: 2026, month: 9),
        today: _today,
      ).mosaic)
        cell.day.day,
    ];

    // round(i × 27 / 15): 0, 2, 4, 5, 7, 9, 11, 13, 14, 16, 18, 20, …
    expect(mosaicOf(<int>[for (int day = 1; day <= 28; day++) day]), <int>[
      1,
      3,
      5,
      6,
      8,
      10,
      12,
      14,
      15,
      17,
      19,
      21,
      23,
      24,
      26,
      28,
    ]);
    expect(mosaicOf(<int>[1, 2, 3]), <int>[
      1,
      2,
      3,
      1,
      2,
      3,
      1,
      2,
      3,
      1,
      2,
      3,
      1,
      2,
      3,
      1,
    ]);
    expect(mosaicOf(<int>[]), isEmpty);
  });

  // September 1–6: 1, 2 and 4 "trip", 2 and 5 private (5 untagged), 3 and
  // 6 "work".
  test('under a tag filter the private clips left out are the filtered '
      "range's, the clips the filter left out are counted, and a day whose "
      'clips are all filtered out is not skipped (it was recorded)', () {
    final ClipIndex index = ClipIndex(
      profile: ProfileKey.defaultProfile,
      clips: <IndexedClip>[
        for (int day = 1; day <= 6; day++)
          IndexedClip(
            ref: _clip('${LocalDay(2026, 9, day).fileStem}.mp4'),
            stamp: const FileStamp(sizeBytes: 1000, modifiedMs: 0),
          ),
      ],
      private: <String>{'2026-09-02.mp4', '2026-09-05.mp4'},
      tags: <String, List<String>>{
        '2026-09-01.mp4': <String>['trip'],
        '2026-09-02.mp4': <String>['trip'],
        '2026-09-03.mp4': <String>['work'],
        '2026-09-04.mp4': <String>['trip'],
        '2026-09-06.mp4': <String>['work'],
      },
    );
    final MovieSource trips = MovieSource.dateRange(
      DayRange(first: LocalDay(2026, 9, 1), last: LocalDay(2026, 9, 6)),
      tags: TagFilter(anyOf: <String>{'trip'}),
    );

    final MovieDraft draft = MovieDraft.of(index, trips, today: _today);

    expect(draft.clips.map((ClipRef clip) => clip.day.day), <int>[1, 4]);
    expect(draft.tags, TagFilter(anyOf: <String>{'trip'}));
    expect(draft.privateLeftOut, 1, reason: 'the 2nd; the 5th is untagged');
    expect(draft.privateInRange, 1);
    expect(draft.tagsLeftOut, 2, reason: 'the 3rd and the 6th');
    expect(draft.skippedDays, isEmpty);
    expect(draft.clipBytes, 2000);

    final MovieDraft included = MovieDraft.of(
      index,
      trips,
      today: _today,
      includePrivate: true,
    );
    expect(included.clips.map((ClipRef clip) => clip.day.day), <int>[1, 2, 4]);
    expect(included.privateIncluded, 1);
    expect(included.privateLeftOut, 0);
    expect(included.tagsLeftOut, 3, reason: 'the 5th too, now in range');
  });
}
