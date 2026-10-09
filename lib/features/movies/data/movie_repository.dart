import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/movies/data/movie_index.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/domain/movie_file_name.dart';
import 'package:one_second_diary/features/movies/domain/movie_listing.dart';

/// My movies: the movies in `Movies/` and its user-made sub-folders, every
/// profile's in one list, with what the [MovieIndex] knows about each, keyed by
/// the path in `Movies/`.
class MovieRepository {
  MovieRepository({
    required this._index,
    required this._publisher,
    required this._prefs,
    required this._paths,
    required this._logger,
  });

  final MovieIndex _index;
  final MediaPublisher _publisher;
  final PrefsStore _prefs;
  final AppPaths _paths;
  final AppLogger _logger;

  static const String _tag = 'MOVIES';

  /// Every movie, newest first.
  Future<List<MovieEntry>> list() async => (await listing()).movies;

  /// Every movie, newest first, and which of them the index knows nothing
  /// about: My movies reads those movies' tags once.
  Future<MovieListing> listing() async {
    final Map<String, MovieEntry> indexed = await _index.entries();
    final Set<String> unindexed = <String>{};
    final List<MovieEntry> movies = <MovieEntry>[];
    for (final String relPath in await _movieFileNames()) {
      final MovieEntry? known = indexed[relPath];
      if (known == null) unindexed.add(relPath);
      movies.add(known ?? await _unindexed(relPath));
    }
    return MovieListing(
      movies: List<MovieEntry>.unmodifiable(movies..sort(_newestFirst)),
      unindexed: Set<String>.unmodifiable(unindexed),
    );
  }

  /// By creation time, newest first. Ties (a folder restored from a backup)
  /// go to the higher movie number, then to the name.
  static int _newestFirst(MovieEntry a, MovieEntry b) {
    final int byTime = b.createdAt.compareTo(a.createdAt);
    if (byTime != 0) return byTime;
    final int byNumber = (MovieFileName.numberOf(b.fileName) ?? 0).compareTo(
      MovieFileName.numberOf(a.fileName) ?? 0,
    );
    return byNumber != 0 ? byNumber : a.fileName.compareTo(b.fileName);
  }

  /// Whether [movie]'s file is still there (the user may have deleted it
  /// from the gallery since it was listed).
  Future<bool> exists(MovieEntry movie) =>
      File('${_paths.movies}${movie.fileName}').exists();

  /// Registers [movie], just published into `Movies/`, and writes `movieCount`
  /// for a downgrade to an older version of the app.
  Future<void> add(MovieEntry movie) async {
    await _writeMovieCount();
    await _index.put(movie);
  }

  /// `movieCount` = 1 + the highest movie number, the number an older version
  /// would give its next movie.
  Future<void> _writeMovieCount() async {
    final int next = await _highestNumber() + 1;
    try {
      await _prefs.write(PrefKeys.movieCount, next);
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not write movieCount $next',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Gives [movie] the base title [title] and returns it renamed.
  Future<MovieEntry> rename({
    required MovieEntry movie,
    required String title,
  }) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be blank');
    }
    final MovieEntry renamed = movie.withTitle(trimmed);
    await _index.put(renamed);
    return renamed;
  }

  /// Records [movie] as it is now (its music turned on or off: the file was
  /// remuxed, `MovieAudio`).
  Future<void> update(MovieEntry movie) => _index.put(movie);

  /// Deletes [movie] from the gallery for good (no Undo: the screen asks first)
  /// and forgets it.
  Future<void> delete(MovieEntry movie) async {
    if (!await _publisher.deleteWithoutUndo(
      '${PathNames.moviesFolder}/${movie.fileName}',
    )) {
      throw MediaStoreException('Could not delete the movie ${movie.fileName}');
    }
    await _index.remove(movie.fileName);
  }

  /// The name of a new movie made on [day]: `OSD-Movie-<n>-<day>.mp4` with n
  /// one past the highest OSD-Movie number in `Movies/` ([_highestNumber]), so
  /// it is free by construction and numbers only ever go up.
  Future<String> nextFreeFileName(LocalDay day) async =>
      MovieFileName.format(number: await _highestNumber() + 1, day: day);

  /// The highest number of an `OSD-Movie-<n>-<yyyy-MM-dd>.mp4` in `Movies/` or
  /// one of its sub-folders (a movie the user moved keeps its number taken); 0
  /// when there is none.
  Future<int> _highestNumber() async {
    int highest = 0;
    for (final String relPath in await _movieFileNames()) {
      final int? number = MovieFileName.numberOf(PathNames.fileNameOf(relPath));
      if (number != null && number > highest) highest = number;
    }
    return highest;
  }

  /// The movie files in `Movies/`, as paths relative to it: `.mp4` files that
  /// are not hidden (Android's `.pending-*` and `.trashed-*` rows), in the
  /// folder and in user-made sub-folders at any depth, never in a hidden folder
  /// (a gallery app's `.thumbnails`), which is not even searched.
  Future<List<String>> _movieFileNames() async {
    final List<String> names = <String>[];
    try {
      await _collect(Directory(_paths.movies), '', names);
    } on PathNotFoundException {
      return const <String>[];
    } on FileSystemException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not list the movies',
        error: error,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(
        StorageException('Could not list the movies', cause: error),
        stackTrace,
      );
    }
    return names;
  }

  /// Adds the movies in [folder] (at [prefix] in `Movies/`) to [names], then
  /// those of its sub-folders.
  Future<void> _collect(
    Directory folder,
    String prefix,
    List<String> names,
  ) async {
    final List<Directory> subFolders = <Directory>[];
    await for (final FileSystemEntity entity in folder.list(
      followLinks: false,
    )) {
      final String name = PathNames.fileNameOf(entity.path);
      if (name.startsWith('.')) continue;
      if (entity is File && name.endsWith('.mp4')) {
        names.add('$prefix$name');
      } else if (entity is Directory) {
        subFolders.add(entity);
      }
    }
    for (final Directory subFolder in subFolders) {
      final String name = PathNames.fileNameOf(subFolder.path);
      try {
        await _collect(subFolder, '$prefix$name/', names);
      } on FileSystemException catch (error, stackTrace) {
        _logger.warning(
          _tag,
          'Could not list the movies in $prefix$name',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// A movie the index knows nothing about (made by an older install, or
  /// copied in): titled by its file name, dated by its modification time.
  Future<MovieEntry> _unindexed(String relPath) async => MovieEntry(
    fileName: relPath,
    title: MovieFileName.titleOf(PathNames.fileNameOf(relPath)),
    profile: null,
    clipCount: null,
    from: null,
    to: null,
    createdAt: (await File('${_paths.movies}$relPath').stat()).modified,
    durationMs: null,
  );
}
