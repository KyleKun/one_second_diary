// A range through a tag filter: "only videos tagged…" keeps the clips
// tagged one of them (by fold key), "leave out videos tagged…" drops them;
// private clips stay out unless included; clips picked by hand ignore it.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/domain/movie_selection.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

final LocalDay _today = LocalDay(2026, 9, 28);

ClipRef _clip(int day) => ClipRef(
  profile: ProfileKey.defaultProfile,
  relPath: '${LocalDay(2026, 9, day).fileStem}.mp4',
);

List<int> _days(Iterable<ClipRef> clips) => <int>[
  for (final ClipRef clip in clips) clip.day.day,
];

void main() {
  // September 1–6: 1 and 4 "Trip", 2 "trip" and "work", 3 "work", 5
  // untagged, 6 "trip" and private.
  final ClipIndex index = ClipIndex(
    profile: ProfileKey.defaultProfile,
    clips: <IndexedClip>[
      for (int day = 1; day <= 6; day++)
        IndexedClip(
          ref: _clip(day),
          stamp: const FileStamp(sizeBytes: 8, modifiedMs: 0),
        ),
    ],
    private: <String>{_clip(6).relPath},
    tags: <String, List<String>>{
      _clip(1).relPath: <String>['Trip'],
      _clip(2).relPath: <String>['trip', 'work'],
      _clip(3).relPath: <String>['work'],
      _clip(4).relPath: <String>['Trip'],
      _clip(6).relPath: <String>['trip'],
    },
  );
  final TagFilter onlyTrip = TagFilter(anyOf: <String>{'TRIP'});
  final TagFilter noWork = TagFilter(noneOf: <String>{'Work'});

  test('a preset, a month and picked days keep the clips tagged as asked, '
      'compared by fold key, and drop the ones tagged as left out; a '
      'private clip is out until included; both count the same', () {
    final List<MovieSource> ranges = <MovieSource>[
      MovieSource.preset(MoviePreset.thisMonth, tags: onlyTrip),
      MovieSource.month(year: 2026, month: 9, tags: onlyTrip),
      MovieSource.dateRange(
        DayRange(first: LocalDay(2026, 9, 1), last: LocalDay(2026, 9, 30)),
        tags: onlyTrip,
      ),
    ];
    for (final MovieSource source in ranges) {
      expect(_days(index.clipsFor(source, today: _today)), <int>[
        1,
        2,
        4,
      ], reason: '$source');
      expect(index.countClipsFor(source, today: _today), 3);
      expect(
        _days(index.clipsFor(source, today: _today, includePrivate: true)),
        <int>[1, 2, 4, 6],
      );
      expect(
        index.countClipsFor(source, today: _today, includePrivate: true),
        4,
      );
    }

    final MovieSource withoutWork = MovieSource.month(
      year: 2026,
      month: 9,
      tags: noWork,
    );
    expect(_days(index.clipsFor(withoutWork, today: _today)), <int>[1, 4, 5]);

    final MovieSource tripNotWork = MovieSource.month(
      year: 2026,
      month: 9,
      tags: TagFilter(anyOf: <String>{'trip'}, noneOf: <String>{'work'}),
    );
    expect(_days(index.clipsFor(tripNotWork, today: _today)), <int>[1, 4]);
  });

  test('a range without a filter is the whole range; clips picked by hand '
      'are taken as picked, whatever their tags; the filter is part of the '
      'source', () {
    expect(
      _days(
        index.clipsFor(
          const MovieSource.month(year: 2026, month: 9),
          today: _today,
        ),
      ),
      <int>[1, 2, 3, 4, 5],
    );
    expect(
      _days(
        index.clipsFor(
          MovieSource.custom(<ClipRef>{_clip(3), _clip(5)}),
          today: _today,
        ),
      ),
      <int>[3, 5],
    );

    const MonthMovieSource plain = MonthMovieSource(year: 2026, month: 9);
    expect(plain.tags.isEmpty, isTrue);
    expect(plain.withTags(onlyTrip), isNot(plain));
    expect(plain.withTags(onlyTrip).withTags(TagFilter.none), plain);
    expect(
      MovieSource.month(year: 2026, month: 9, tags: TagFilter()),
      plain,
      reason: 'an empty filter is no filter',
    );
  });
}
