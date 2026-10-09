import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/movies/data/movie_index.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';

final MovieEntry _kids = MovieEntry(
  fileName: 'OSD-Movie-3-2025-12-31.mp4',
  title: '2025',
  profile: const ProfileKey('Kids'),
  clipCount: 340,
  from: LocalDay(2025, 1, 1),
  to: LocalDay(2025, 12, 31),
  createdAt: DateTime(2025, 12, 31, 21, 30),
  durationMs: 680000,
);

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late FakeClock clock;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    clock = FakeClock(DateTime(2026, 1, 2, 9, 30));
  });

  MovieIndex open() =>
      MovieIndex(paths: paths, logger: memoryLogger(sink), clock: clock);

  test('every movie put in the index is read back after a restart, as it '
      'was: a Default movie with its empty key, a renamed v1.x movie with no '
      'profile and no facts, a canvas or none, a sub-folder movie keyed by '
      'its path in Movies/ (decision O8); a removed one is gone; the sidecar '
      'holds no path (invariant 17)', () async {
    final MovieEntry defaultMovie = MovieEntry(
      fileName: 'OSD-Movie-4-2026-01-02.mp4',
      title: 'Holidays',
      profile: ProfileKey.defaultProfile,
      clipCount: 12,
      from: LocalDay(2025, 12, 20),
      to: LocalDay(2026, 1, 1),
      createdAt: DateTime(2026, 1, 2, 9),
      durationMs: 24000,
      orientation: VideoOrientation.portrait,
    );
    final MovieEntry legacyMovie = MovieEntry(
      fileName: 'OneSecondDiary-Movie-2-2022-06-01.mp4',
      title: 'First summer',
      profile: null,
      clipCount: null,
      from: null,
      to: null,
      createdAt: DateTime(2022, 6, 1, 18),
      durationMs: null,
    );
    final MovieEntry trip = MovieEntry(
      fileName: 'Trips/OSD-Movie-6-2026-01-02.mp4',
      title: 'Japan',
      profile: ProfileKey.defaultProfile,
      clipCount: 9,
      from: LocalDay(2025, 10, 1),
      to: LocalDay(2025, 10, 9),
      createdAt: DateTime(2026, 1, 2, 10),
      durationMs: 13500,
    );
    final MovieIndex index = open();
    for (final MovieEntry movie in <MovieEntry>[
      _kids,
      defaultMovie,
      legacyMovie,
      trip,
    ]) {
      await index.put(movie);
    }

    expect(await open().entries(), <String, MovieEntry>{
      _kids.fileName: _kids,
      defaultMovie.fileName: defaultMovie,
      legacyMovie.fileName: legacyMovie,
      'Trips/OSD-Movie-6-2026-01-02.mp4': trip,
    });

    await open().remove(trip.fileName);
    expect((await open().entries()).keys, isNot(contains(trip.fileName)));

    // The sidecar: movies_v1.json in the support index folder, holding file
    // names and profile keys, never paths.
    final String json = await File(
      '${paths.supportIndexDir}/movies_v1.json',
    ).readAsString();
    expect(json, contains('"OSD-Movie-3-2025-12-31.mp4"'));
    expect(json, contains('"profile":"Kids"'));
    expect(json, isNot(contains('/')));
  });

  test('putIfAbsent records a movie the index does not know, and keeps the '
      'entry it has (a rename) otherwise, giving what the index holds; one '
      'that cannot be saved throws and records nothing', () async {
    final MovieIndex index = open();

    expect(await index.putIfAbsent(_kids), _kids);
    final MovieEntry renamed = _kids.withTitle('Our year');
    await index.put(renamed);
    expect(await index.putIfAbsent(_kids), renamed);
    expect(await open().entries(), <String, MovieEntry>{
      _kids.fileName: renamed,
    });

    // A file where the index folder should be: every save fails.
    final AppPaths other = await createTestPaths();
    final MovieIndex blocked = MovieIndex(
      paths: other,
      logger: memoryLogger(sink),
      clock: clock,
    );
    await blocked.entries();
    await File(other.supportIndexDir).writeAsString('in the way');
    await expectLater(
      blocked.putIfAbsent(_kids),
      throwsA(isA<StorageException>()),
    );
    expect(await blocked.entries(), isEmpty);
  });

  test('writes made at the same time all persist (a movie finishing while '
      'another is renamed)', () async {
    final MovieIndex index = open();
    final List<MovieEntry> movies = <MovieEntry>[
      for (int n = 1; n <= 5; n++)
        MovieEntry(
          fileName: 'OSD-Movie-$n-2026-01-0$n.mp4',
          title: 'Movie $n',
          profile: ProfileKey.defaultProfile,
          clipCount: n + 1,
          from: LocalDay(2025, 12, 1),
          to: LocalDay(2025, 12, 31),
          createdAt: DateTime(2026, 1, n),
          durationMs: 1000 * n,
        ),
    ];

    await Future.wait(<Future<void>>[
      for (final MovieEntry movie in movies) index.put(movie),
    ]);

    expect(await open().entries(), <String, MovieEntry>{
      for (final MovieEntry movie in movies) movie.fileName: movie,
    });
  });

  test('a save that fails throws a StorageException and changes nothing; '
      'later saves still work', () async {
    final MovieEntry renamed = _kids.withTitle('Our year');
    final MovieIndex index = open();
    await index.put(_kids);
    // A file where the index folder should be: every save fails.
    await Directory(paths.supportIndexDir).delete(recursive: true);
    await File(paths.supportIndexDir).writeAsString('in the way');

    await expectLater(index.put(renamed), throwsA(isA<StorageException>()));

    expect((await index.entries())[_kids.fileName], _kids);
    expect(sink.lines.last, contains('[ERROR]'));
    await File(paths.supportIndexDir).delete();
    await index.remove(_kids.fileName);
    expect(await open().entries(), isEmpty);
  });

  test('an unreadable sidecar reads as empty, is logged and is moved aside '
      'before the next save, so the renamed titles it holds are never '
      'overwritten', () async {
    final String sidecar = '${paths.supportIndexDir}/movies_v1.json';
    await Directory(paths.supportIndexDir).create(recursive: true);
    const String truncated =
        '{"version":1,"movies":{"OSD-Movie-1-2025-01-05.mp4":'
        '{"title":"My trip","createdAt":17';
    await File(sidecar).writeAsString(truncated);
    final MovieIndex index = open();

    expect(await index.entries(), isEmpty);
    await index.put(_kids);

    final String asideName =
        'movies_v1.json.corrupt-${clock.now().millisecondsSinceEpoch}';
    expect(
      await File('${paths.supportIndexDir}/$asideName').readAsString(),
      truncated,
    );
    expect(
      sink.lines.where((String line) => line.contains('[WARNING]')),
      contains(contains(asideName)),
    );
    expect(await open().entries(), <String, MovieEntry>{_kids.fileName: _kids});
  });
}
