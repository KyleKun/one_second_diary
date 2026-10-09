import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/pref_key.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/movies/data/movie_index.dart';
import 'package:one_second_diary/features/movies/data/movie_repository.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/domain/movie_listing.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/locked_folder.dart';

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late MovieIndex index;
  late MovieRepository movies;
  late PrefsStore prefs;
  late FakeMediaStoreGateway gallery;

  MovieIndex newIndex() => MovieIndex(
    paths: paths,
    logger: memoryLogger(sink),
    clock: FakeClock(DateTime(2026, 9, 29, 10)),
  );

  /// A repository over the same folders, as after a restart.
  MovieRepository repository({PrefsStore? prefsStore}) => MovieRepository(
    index: newIndex(),
    publisher: MediaPublisher(
      gateway: gallery,
      paths: paths,
      logger: memoryLogger(sink),
      clock: FakeClock(DateTime(2026, 9, 29, 10)),
    ),
    prefs: prefsStore ?? prefs,
    paths: paths,
    logger: memoryLogger(sink),
  );

  setUp(() async {
    paths = await createTestPaths();
    prefs = await openLegacyPrefs(legacyPrefs(movieCount: 1));
    sink = MemoryLogSink();
    gallery = FakeMediaStoreGateway.onDisk(paths);
    index = newIndex();
    movies = MovieRepository(
      index: index,
      publisher: MediaPublisher(
        gateway: gallery,
        paths: paths,
        logger: memoryLogger(sink),
        clock: FakeClock(DateTime(2026, 9, 29, 10)),
      ),
      prefs: prefs,
      paths: paths,
      logger: memoryLogger(sink),
    );
  });

  /// A movie file in `Movies/` last modified at [modified].
  Future<void> seedMovie(String fileName, DateTime modified) async {
    final File file = await seedFile(paths, 'Movies/$fileName');
    await file.setLastModified(modified);
  }

  /// How a movie with no index entry is listed.
  MovieEntry unindexed(String fileName, String title, DateTime modified) =>
      MovieEntry(
        fileName: fileName,
        title: title,
        profile: null,
        clipCount: null,
        from: null,
        to: null,
        createdAt: modified,
        durationMs: null,
      );

  group('list', () {
    // Movies in user-made sub-folders of Movies/ are listed too.
    test(
      'lists v1.x movies newest first by modification time, titled with '
      'the date in their name; a movie the user named by its file name; a '
      'movie in a sub-folder of Movies/, however deep, by its path in '
      'Movies/ (decision O8); equal times by movie number, then name',
      () async {
        await seedMovie('OSD-Movie-9-2024-03-01.mp4', DateTime(2024, 3, 1, 20));
        await seedMovie(
          'OneSecondDiary-Movie-2-2022-01-01.mp4',
          DateTime(2022, 1, 1, 12),
        );
        await seedMovie('Summer in Japan.mp4', DateTime(2025, 8, 30));
        await seedMovie('Old/OSD-Movie-5-2025-03-01.mp4', DateTime(2025, 3, 1));
        await seedMovie('Trips/Japan/Kyoto.mp4', DateTime(2025, 4, 1));
        // Restored from a backup: the same time.
        final DateTime restored = DateTime(2026, 3, 1, 12);
        await seedMovie('A trip.mp4', restored);
        await seedMovie('OSD-Movie-2-2025-01-01.mp4', restored);
        await seedMovie('OSD-Movie-10-2025-06-01.mp4', restored);

        expect(await movies.list(), <MovieEntry>[
          unindexed('OSD-Movie-10-2025-06-01.mp4', '2025-06-01', restored),
          unindexed('OSD-Movie-2-2025-01-01.mp4', '2025-01-01', restored),
          unindexed('A trip.mp4', 'A trip', restored),
          unindexed(
            'Summer in Japan.mp4',
            'Summer in Japan',
            DateTime(2025, 8, 30),
          ),
          unindexed('Trips/Japan/Kyoto.mp4', 'Kyoto', DateTime(2025, 4, 1)),
          unindexed(
            'Old/OSD-Movie-5-2025-03-01.mp4',
            '2025-03-01',
            DateTime(2025, 3, 1),
          ),
          unindexed(
            'OSD-Movie-9-2024-03-01.mp4',
            '2024-03-01',
            DateTime(2024, 3, 1, 20),
          ),
          unindexed(
            'OneSecondDiary-Movie-2-2022-01-01.mp4',
            '2022-01-01',
            DateTime(2022, 1, 1, 12),
          ),
        ]);
      },
    );

    test("lists every profile's movies in one list with their index facts, "
        'newest first by creation time (decision D3), and says which movies '
        'the index knows nothing about (decision O9 probes those)', () async {
      final MovieEntry kids = MovieEntry(
        fileName: 'OSD-Movie-12-2025-12-31.mp4',
        title: '2025',
        profile: const ProfileKey('Kids'),
        clipCount: 340,
        from: LocalDay(2025, 1, 1),
        to: LocalDay(2025, 12, 31),
        createdAt: DateTime(2025, 12, 31, 21),
        durationMs: 680000,
      );
      final MovieEntry september = MovieEntry(
        fileName: 'OSD-Movie-11-2025-10-01.mp4',
        title: 'September 2025',
        profile: ProfileKey.defaultProfile,
        clipCount: 25,
        from: LocalDay(2025, 9, 1),
        to: LocalDay(2025, 9, 30),
        createdAt: DateTime(2025, 10, 1, 8),
        durationMs: 50000,
      );
      // Copied back from a backup: its mtime says nothing about its age.
      await seedMovie(kids.fileName, DateTime(2026, 2, 1));
      await seedMovie(september.fileName, DateTime(2026, 2, 2));
      await seedMovie('Trips/OSD-Movie-10-2025-11-15.mp4', DateTime(2025, 11));
      await index.put(kids);
      await index.put(september);

      final List<MovieEntry> expected = <MovieEntry>[
        kids,
        unindexed(
          'Trips/OSD-Movie-10-2025-11-15.mp4',
          '2025-11-15',
          DateTime(2025, 11),
        ),
        september,
      ];
      expect(await movies.list(), expected);
      final MovieListing listing = await movies.listing();
      expect(listing.movies, expected);
      expect(listing.unindexed, <String>{'Trips/OSD-Movie-10-2025-11-15.mp4'});
    });

    test(
      'skips what is not a movie (other files, hidden and pending media '
      'store files, hidden folders) and a movie deleted outside the app, '
      'even when the index knows it; no Movies folder is no movies',
      () async {
        await seedMovie('OSD-Movie-1-2025-01-01.mp4', DateTime(2025, 1, 1));
        await seedFile(paths, 'Movies/.DS_Store');
        await seedFile(paths, 'Movies/poster.jpg');
        await seedFile(paths, 'Movies/OSD-Movie-2-2025-02-01.MP4');
        await seedFile(paths, 'Movies/.pending-1767000000-OSD-Movie-3.mp4');
        await seedFile(paths, 'Movies/.trashed-1767000000-OSD-Movie-4.mp4');
        await seedFile(paths, 'Movies/.thumbnails/OSD-Movie-5-2025-02-01.mp4');
        await seedFile(
          paths,
          'Movies/Trips/.hidden/OSD-Movie-6-2025-03-01.mp4',
        );
        await index.put(
          MovieEntry(
            fileName: 'OSD-Movie-7-2025-01-01.mp4',
            title: 'Deleted in the Gallery',
            profile: ProfileKey.defaultProfile,
            clipCount: 2,
            from: LocalDay(2024, 12, 30),
            to: LocalDay(2024, 12, 31),
            createdAt: DateTime(2025, 1, 1),
            durationMs: 4000,
          ),
        );

        final MovieEntry movie = (await movies.list()).single;
        expect(movie.fileName, 'OSD-Movie-1-2025-01-01.mp4');

        // Deleted from the gallery since it was listed.
        expect(await movies.exists(movie), isTrue);
        await File('${paths.movies}${movie.fileName}').delete();
        expect(await movies.exists(movie), isFalse);

        await Directory(paths.movies).delete(recursive: true);
        expect(await movies.list(), isEmpty);
      },
    );

    test('an unreadable Movies folder (storage permission revoked) is a '
        'StorageException, never an empty list', () async {
      await seedMovie('OSD-Movie-1-2025-01-01.mp4', DateTime(2025));
      if (!await lockFolder(paths.movies)) return;

      await expectLater(movies.list(), throwsA(isA<StorageException>()));
      await expectLater(
        movies.nextFreeFileName(LocalDay(2026, 9, 29)),
        throwsA(isA<StorageException>()),
      );
    });
  });

  test('nextFreeFileName: the first movie is OSD-Movie-1-<day>.mp4, later '
      'ones continue after the highest OSD-Movie number anywhere in Movies/ '
      '(decision O8), so a number never comes back; other names and a number '
      'past 64 bits never steer it', () async {
    final LocalDay day = LocalDay(2026, 9, 29);
    expect(await movies.nextFreeFileName(day), 'OSD-Movie-1-2026-09-29.mp4');

    const String huge = 'OSD-Movie-99999999999999999999-2024-01-05.mp4';
    await seedMovie('OSD-Movie-3-2024-01-01.mp4', DateTime(2024, 1, 1));
    await seedMovie('OSD-Movie-7-2025-05-05.mp4', DateTime(2025, 5, 5));
    await seedMovie('Trips/OSD-Movie-9-2025-05-06.mp4', DateTime(2025, 5, 6));
    await seedMovie('OneSecondDiary-Movie-12-2022-01-01.mp4', DateTime(2022));
    await seedMovie('OSD-Movie-40-2025-02-30.mp4', DateTime(2025, 3, 2));
    await seedMovie(huge, DateTime(2024, 1, 5));

    expect(await movies.nextFreeFileName(day), 'OSD-Movie-10-2026-09-29.mp4');
    expect(
      (await movies.list()).map((MovieEntry movie) => movie.fileName),
      contains(huge),
    );
  });

  test('add registers a new movie and sets movieCount one past the highest '
      'number, so v1.7 after a downgrade never overwrites it (CONTRACTS '
      '§3.4); a refused movieCount write is logged and the movie is still '
      'registered', () async {
    await seedMovie('OSD-Movie-7-2025-05-05.mp4', DateTime(2025, 5, 5));
    await seedMovie('OSD-Movie-8-2026-09-29.mp4', DateTime(2026, 9, 29, 10));
    MovieEntry made(int number) => MovieEntry(
      fileName: 'OSD-Movie-$number-2026-09-29.mp4',
      title: 'September 2026',
      profile: ProfileKey.defaultProfile,
      clipCount: 25,
      from: LocalDay(2026, 9, 1),
      to: LocalDay(2026, 9, 28),
      createdAt: DateTime(2026, 9, 29, 10 + number),
      durationMs: 50000,
    );

    await movies.add(made(8));
    expect((await movies.list()).first, made(8));
    expect(prefs.read(PrefKeys.movieCount), 9);

    await seedMovie('OSD-Movie-9-2026-09-29.mp4', DateTime(2026, 9, 29, 19));
    final MovieRepository refusing = repository(prefsStore: _RefusingPrefs());
    await refusing.add(made(9));
    expect((await refusing.list()).first, made(9));
    expect(prefs.read(PrefKeys.movieCount), 9);
    expect(
      sink.lines,
      contains(allOf(contains('[WARNING]'), contains('movieCount'))),
    );
  });

  test('rename changes only the title, trimmed: the file keeps its name, '
      'bytes and date, a sub-folder movie its path in Movies/ (decision O8), '
      'the title survives a restart (M10); a blank title is refused', () async {
    await seedMovie('Trips/OSD-Movie-4-2025-12-31.mp4', DateTime(2025, 12, 31));
    final File file = File('${paths.movies}Trips/OSD-Movie-4-2025-12-31.mp4');
    final MovieEntry movie = (await movies.list()).single;

    final MovieEntry renamed = await movies.rename(
      movie: movie,
      title: '  Summer in Japan \n',
    );

    expect(renamed, movie.withTitle('Summer in Japan'));
    expect(renamed.fileName, 'Trips/OSD-Movie-4-2025-12-31.mp4');
    expect(await file.readAsBytes(), fakeVideoBytes);
    expect(await file.lastModified(), DateTime(2025, 12, 31));
    await expectLater(
      movies.rename(movie: renamed, title: ' \t '),
      throwsArgumentError,
    );
    expect(await repository().list(), <MovieEntry>[renamed]);
  });

  test('delete removes the file through the gallery with its own album, keeps '
      'no backup (M9 asks first; no Undo for movies) and forgets its title; '
      'a refused delete (Android consent declined) throws a '
      'MediaStoreException and keeps the movie and its title', () async {
    await seedMovie('OSD-Movie-4-2025-12-31.mp4', DateTime(2025, 12, 31));
    await seedMovie('Trips/OSD-Movie-5-2026-01-01.mp4', DateTime(2026));
    final MovieEntry renamed = await movies.rename(
      movie: (await movies.list()).last,
      title: 'New year',
    );

    gallery.deleteResults.add(false);
    await expectLater(
      movies.delete(renamed),
      throwsA(isA<MediaStoreException>()),
    );
    expect(await movies.list(), contains(renamed));

    await movies.delete(renamed);
    await movies.delete((await movies.list()).single);

    expect(gallery.calls.skip(1), <MediaStoreCall>[
      DeleteCall(
        absolutePath: '${paths.movies}OSD-Movie-4-2025-12-31.mp4',
        album: 'OneSecondDiary/Movies',
      ),
      DeleteCall(
        absolutePath: '${paths.movies}Trips/OSD-Movie-5-2026-01-01.mp4',
        album: 'OneSecondDiary/Movies/Trips',
      ),
    ]);
    expect(await Directory(paths.trashDir).exists(), isFalse);
    expect(await movies.list(), isEmpty);
    expect(await newIndex().entries(), isEmpty);
  });
}

/// A preference store whose every write is refused by the platform.
class _RefusingPrefs extends Fake implements PrefsStore {
  @override
  Future<void> write<T>(PrefKey<T> key, T value) async =>
      throw StorageException('The platform refused to write "${key.name}"');
}
