import 'dart:convert';

import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// The JSON format of `movies_v1.json`:
///
/// ```json
/// {"version": 1, "movies": {"OSD-Movie-3-2025-12-31.mp4":
///   {"title": "2025", "profile": "Kids", "clipCount": 340,
///    "from": "2025-01-01", "to": "2025-12-31",
///    "createdAt": 1767213000000, "durationMs": 680000,
///    "orientation": "portrait", "privateClips": 3,
///    "tags": ["trip"], "without": ["work"]}}}
/// ```
///
/// Keys are paths relative to `Movies/`: the file name, or
/// `Trips/<name>` for a movie in a user-made sub-folder; never an absolute
/// path. `profile` is the immutable profile key (`""` for Default, absent
/// for a movie made by an older install), never a display name. Days are
/// `yyyy-MM-dd`; `createdAt` is milliseconds since the epoch. Unknown facts
/// are left out, and so is `privateClips` for a movie without private clips
/// and `tags` / `without` for one made without a tag filter, `chapters`
/// for a movie without any, `transition` (`fade`, `black`, `white`)
/// for a movie of hard cuts, and `music` (`true` playing, `false` turned
/// off) for a movie without music.
abstract final class MovieIndexSidecar {
  static const int version = 1;

  static String encode(Map<String, MovieEntry> movies) =>
      jsonEncode(<String, Object?>{
        'version': version,
        'movies': <String, Object?>{
          for (final MapEntry<String, MovieEntry> entry in movies.entries)
            entry.key: _encodeEntry(entry.value),
        },
      });

  /// The movies in [json], by file name.
  static Map<String, MovieEntry> decode(String json) {
    final Object? root = jsonDecode(json);
    if (root is! Map<String, Object?> || root['version'] != version) {
      throw const FormatException('Not a movie index of version 1');
    }
    final Object? movies = root['movies'];
    if (movies is! Map<String, Object?>) {
      throw const FormatException('The movie index has no movies');
    }
    return <String, MovieEntry>{
      for (final MapEntry<String, Object?> entry in movies.entries)
        if (_decodeEntry(entry.key, entry.value) case final MovieEntry movie)
          entry.key: movie,
    };
  }

  static Map<String, Object?> _encodeEntry(MovieEntry movie) =>
      <String, Object?>{
        'title': movie.title,
        'profile': ?movie.profile?.value,
        'clipCount': ?movie.clipCount,
        'from': ?movie.from?.fileStem,
        'to': ?movie.to?.fileStem,
        'createdAt': movie.createdAt.millisecondsSinceEpoch,
        'durationMs': ?movie.durationMs,
        'orientation': ?movie.orientation?.name,
        if (movie.privateClipCount > 0) 'privateClips': movie.privateClipCount,
        if (movie.tags.isNotEmpty) 'tags': movie.tags,
        if (movie.without.isNotEmpty) 'without': movie.without,
        'transition': ?movie.transition?.tag,
        'music': ?movie.musicOn,
        if (movie.chapters.isNotEmpty)
          'chapters': <Object?>[
            for (final MovieChapter chapter in movie.chapters)
              <String, Object?>{
                'start': chapter.startMs,
                'end': chapter.endMs,
                'title': chapter.title,
              },
          ],
      };

  static MovieEntry? _decodeEntry(String fileName, Object? value) {
    if (value is! Map<String, Object?>) return null;
    if (value case {
      'title': final String title,
      'createdAt': final int createdAtMs,
    }) {
      return MovieEntry(
        fileName: fileName,
        title: title,
        profile: switch (value['profile']) {
          final String key => ProfileKey(key),
          _ => null,
        },
        clipCount: _as<int>(value['clipCount']),
        from: _dayOf(value['from']),
        to: _dayOf(value['to']),
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
        durationMs: _as<int>(value['durationMs']),
        orientation: switch (value['orientation']) {
          final String name => VideoOrientation.values.asNameMap()[name],
          _ => null,
        },
        privateClipCount: _as<int>(value['privateClips']) ?? 0,
        tags: _strings(value['tags']),
        without: _strings(value['without']),
        chapters: _chapters(value['chapters']),
        transition: MovieTransition.fromTag(_as<String>(value['transition'])),
        musicOn: _as<bool>(value['music']),
      );
    }
    return null;
  }

  /// The chapters of a JSON list (`{"start": ms, "end": ms, "title": …}`);
  /// a malformed one is dropped, anything else is empty.
  static List<MovieChapter> _chapters(Object? value) => value is List<Object?>
      ? List<MovieChapter>.unmodifiable(<MovieChapter>[
          for (final Object? item in value)
            if (item case {
              'start': final int start,
              'end': final int end,
              'title': final String title,
            })
              MovieChapter(startMs: start, endMs: end, title: title),
        ])
      : const <MovieChapter>[];

  static T? _as<T>(Object? value) => value is T ? value : null;

  /// The strings of a JSON list; anything else is empty.
  static List<String> _strings(Object? value) => value is List<Object?>
      ? List<String>.unmodifiable(value.whereType<String>())
      : const <String>[];

  static LocalDay? _dayOf(Object? value) =>
      value is String ? LocalDay.tryParseStem(value) : null;
}
