// The movie index sidecar keeps a movie's tag filter and its chapters, and
// leaves the keys out for a movie made without, so an older build reads the
// file as before.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/movies/data/movie_index_sidecar.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

MovieEntry _movie({
  List<String> tags = const <String>[],
  List<String> without = const <String>[],
  List<MovieChapter> chapters = const <MovieChapter>[],
  MovieTransition? transition,
  bool? musicOn,
}) => MovieEntry(
  fileName: 'OSD-Movie-3-2025-12-31.mp4',
  title: '2025',
  profile: const ProfileKey('Kids'),
  clipCount: 340,
  from: LocalDay(2025, 1, 1),
  to: LocalDay(2025, 12, 31),
  createdAt: DateTime.fromMillisecondsSinceEpoch(1767213000000),
  durationMs: 680000,
  tags: tags,
  without: without,
  chapters: chapters,
  transition: transition,
  musicOn: musicOn,
);

void main() {
  test('a tag filter survives the round trip as `tags` and `without`; a '
      'movie without one writes neither key and reads back with none', () {
    final MovieEntry filtered = _movie(
      tags: <String>['kids', 'trip'],
      without: <String>['work'],
    );
    final String json = MovieIndexSidecar.encode(<String, MovieEntry>{
      filtered.fileName: filtered,
    });
    final Map<String, Object?> entry =
        ((jsonDecode(json) as Map<String, Object?>)['movies']!
                as Map<String, Object?>)[filtered.fileName]!
            as Map<String, Object?>;
    expect(entry['tags'], <String>['kids', 'trip']);
    expect(entry['without'], <String>['work']);
    expect(MovieIndexSidecar.decode(json)[filtered.fileName], filtered);

    final MovieEntry plain = _movie();
    final String plainJson = MovieIndexSidecar.encode(<String, MovieEntry>{
      plain.fileName: plain,
    });
    expect(plainJson, isNot(contains('"tags"')));
    expect(plainJson, isNot(contains('"without"')));
    final MovieEntry? read = MovieIndexSidecar.decode(
      plainJson,
    )[plain.fileName];
    expect(read, plain);
    expect(read?.hasTagFilter, isFalse);
  });

  test('chapters survive the round trip as `chapters` (start, end, title), '
      'a malformed one dropped; a movie without any writes no key and '
      'reads back with none', () {
    final MovieEntry chaptered = _movie(
      chapters: const <MovieChapter>[
        MovieChapter(startMs: 0, endMs: 1500, title: 'January 1, 2025'),
        MovieChapter(startMs: 1500, endMs: 2500, title: 'January 2, 2025'),
      ],
    );
    final String json = MovieIndexSidecar.encode(<String, MovieEntry>{
      chaptered.fileName: chaptered,
    });
    final Map<String, Object?> entry =
        ((jsonDecode(json) as Map<String, Object?>)['movies']!
                as Map<String, Object?>)[chaptered.fileName]!
            as Map<String, Object?>;
    expect(entry['chapters'], <Map<String, Object?>>[
      <String, Object?>{'start': 0, 'end': 1500, 'title': 'January 1, 2025'},
      <String, Object?>{'start': 1500, 'end': 2500, 'title': 'January 2, 2025'},
    ]);
    expect(MovieIndexSidecar.decode(json)[chaptered.fileName], chaptered);

    final String edited = json.replaceFirst(
      '{"start":1500,"end":2500,"title":"January 2, 2025"}',
      '{"start":"1500","title":"January 2, 2025"}',
    );
    expect(edited, isNot(json));
    expect(
      MovieIndexSidecar.decode(edited)[chaptered.fileName]?.chapters,
      chaptered.chapters.sublist(0, 1),
    );

    final MovieEntry plain = _movie();
    final String plainJson = MovieIndexSidecar.encode(<String, MovieEntry>{
      plain.fileName: plain,
    });
    expect(plainJson, isNot(contains('"chapters"')));
    expect(MovieIndexSidecar.decode(plainJson)[plain.fileName], plain);
  });

  test('a transition survives the round trip as `transition` (its tag); a '
      'movie of hard cuts writes no key, and an unknown tag reads as none '
      '(D27)', () {
    final MovieEntry faded = _movie(transition: MovieTransition.crossfade);
    final String json = MovieIndexSidecar.encode(<String, MovieEntry>{
      faded.fileName: faded,
    });
    expect(json, contains('"transition":"fade"'));
    expect(MovieIndexSidecar.decode(json)[faded.fileName], faded);
    expect(
      MovieIndexSidecar.decode(
        json.replaceFirst('"transition":"fade"', '"transition":"wipe"'),
      )[faded.fileName],
      _movie(),
    );

    final MovieEntry plain = _movie();
    final String plainJson = MovieIndexSidecar.encode(<String, MovieEntry>{
      plain.fileName: plain,
    });
    expect(plainJson, isNot(contains('"transition"')));
    expect(MovieIndexSidecar.decode(plainJson)[plain.fileName], plain);
  });

  test('music survives the round trip as `music` (true playing, false '
      'turned off); a movie without music writes no key (D28)', () {
    for (final bool on in <bool>[true, false]) {
      final MovieEntry scored = _movie(musicOn: on);
      final String json = MovieIndexSidecar.encode(<String, MovieEntry>{
        scored.fileName: scored,
      });
      expect(json, contains('"music":$on'));
      expect(MovieIndexSidecar.decode(json)[scored.fileName], scored);
    }
    final MovieEntry plain = _movie();
    expect(
      MovieIndexSidecar.encode(<String, MovieEntry>{plain.fileName: plain}),
      isNot(contains('"music"')),
    );
  });
}
