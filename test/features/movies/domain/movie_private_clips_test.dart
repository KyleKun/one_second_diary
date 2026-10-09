// A range leaves out the private clips unless the user includes them;
// clips picked by hand are taken as picked. The draft says what it did.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/movies/domain/movie_draft.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/domain/movie_selection.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/domain/movie_tags.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

final LocalDay _today = LocalDay(2026, 9, 28);

ClipRef _clip(int day) => ClipRef(
  profile: ProfileKey.defaultProfile,
  relPath: '${LocalDay(2026, 9, day).fileStem}.mp4',
);

/// One clip on each of [days] of September 2026, those of [private]
/// marked private.
ClipIndex _september(Iterable<int> days, {Iterable<int> private = const []}) =>
    ClipIndex(
      profile: ProfileKey.defaultProfile,
      clips: <IndexedClip>[
        for (final int day in days)
          IndexedClip(
            ref: _clip(day),
            stamp: const FileStamp(sizeBytes: 1000, modifiedMs: 0),
          ),
      ],
      private: <String>{for (final int day in private) _clip(day).relPath},
    );

List<int> _days(Iterable<ClipRef> clips) => <int>[
  for (final ClipRef clip in clips) clip.day.day,
];

List<int> _dates(Iterable<LocalDay> days) => <int>[
  for (final LocalDay day in days) day.day,
];

void main() {
  final ClipIndex index = _september(<int>[1, 2, 3, 5], private: <int>[2, 5]);
  const MovieSource month = MovieSource.month(year: 2026, month: 9);

  test('a range leaves the private clips out of the movie and its count '
      'unless they are included; a day whose clip is private is not a '
      'skipped day; the draft counts what it left out and what it holds', () {
    expect(_days(index.clipsFor(month, today: _today)), <int>[1, 3]);
    expect(index.countClipsFor(month, today: _today), 2);
    expect(
      _days(index.clipsFor(month, today: _today, includePrivate: true)),
      <int>[1, 2, 3, 5],
    );
    expect(
      index.countClipsFor(
        const MovieSource.preset(MoviePreset.allTime),
        today: _today,
        includePrivate: true,
      ),
      4,
    );

    final MovieDraft without = MovieDraft.of(index, month, today: _today);
    expect(_days(without.clips), <int>[1, 3]);
    expect(without.clipBytes, 2000);
    expect(without.includePrivate, isFalse);
    expect(without.privateLeftOut, 2);
    expect(without.privateIncluded, 0);
    expect(without.privateInRange, 2);
    expect(_dates(without.skippedDays), isNot(contains(5)));
    expect(_dates(without.skippedDays), contains(4));

    final MovieDraft with_ = MovieDraft.of(
      index,
      month,
      today: _today,
      includePrivate: true,
    );
    expect(_days(with_.clips), <int>[1, 2, 3, 5]);
    expect(with_.privateLeftOut, 0);
    expect(with_.privateIncluded, 2);
    expect(with_.privateInRange, 2);
  });

  test('clips picked by hand are taken as picked, private or not, and have '
      'no range to include private clips of', () {
    final MovieSource picked = MovieSource.custom(<ClipRef>{
      _clip(5),
      _clip(1),
    });

    expect(_days(index.clipsFor(picked, today: _today)), <int>[1, 5]);

    final MovieDraft draft = MovieDraft.of(index, picked, today: _today);
    expect(_days(draft.clips), <int>[1, 5]);
    expect(draft.privateIncluded, 1);
    expect(draft.privateLeftOut, 0);
    expect(draft.privateInRange, 0);
  });

  test('a movie with private clips says how many in its description, and '
      'one without says nothing of them', () {
    expect(
      MovieTags.describe(
        clips: 4,
        from: LocalDay(2026, 9, 1),
        to: LocalDay(2026, 9, 5),
        privateClips: 2,
      ),
      'clips=4;from=2026-09-01;to=2026-09-05;private=2',
    );
    expect(
      MovieTags.describe(
        clips: 2,
        from: LocalDay(2026, 9, 1),
        to: LocalDay(2026, 9, 3),
      ),
      'clips=2;from=2026-09-01;to=2026-09-03',
    );
    expect(
      const MovieTags(
        description: 'private=2;clips=4;from=2026-09-01;to=2026-09-05',
      ).privateClipCount,
      2,
    );
    for (final String? description in <String?>[
      null,
      'clips=4;from=2026-09-01;to=2026-09-05',
      'clips=4;from=2026-09-01;to=2026-09-05;private=0',
      'private=some',
    ]) {
      expect(
        MovieTags(description: description).privateClipCount,
        0,
        reason: '$description',
      );
    }
  });
}
