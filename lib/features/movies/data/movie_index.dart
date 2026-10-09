import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/movies/data/movie_index_sidecar.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';

/// What the app knows about its movies beyond the file: title, profile, clip
/// count, days covered, creation time and duration.
class MovieIndex {
  MovieIndex({
    required this._paths,
    required this._logger,
    required this._clock,
  });

  final AppPaths _paths;
  final AppLogger _logger;
  final Clock _clock;

  static const String fileName = 'movies_v1.json';
  static const String _tag = 'MOVIES';

  /// The entries, read once and shared by every caller.
  Future<Map<String, MovieEntry>>? _loading;

  /// The last save queued; each save waits for the one before it.
  Future<void> _saving = Future<void>.value();

  String get _file => '${_paths.supportIndexDir}/$fileName';

  /// Every indexed movie, by file name.
  Future<Map<String, MovieEntry>> entries() async =>
      Map<String, MovieEntry>.unmodifiable(await _loaded());

  /// Records [movie] under its file name and saves the index. Throws a
  /// [StorageException] (and records nothing) when the save fails.
  Future<void> put(MovieEntry movie) => _change(movie.fileName, movie);

  /// Records [movie] unless the index already has an entry under its file name
  /// (the user renamed it meanwhile), and gives the entry the index then holds.
  Future<MovieEntry> putIfAbsent(MovieEntry movie) async {
    final Map<String, MovieEntry> entries = await _loaded();
    final MovieEntry? known = entries[movie.fileName];
    if (known != null) return known;
    await _commit(entries, movie.fileName, movie);
    return movie;
  }

  /// Forgets the movie named [fileName] and saves the index. Throws a
  /// [StorageException] (and forgets nothing) when the save fails.
  Future<void> remove(String fileName) => _change(fileName, null);

  Future<void> _change(String fileName, MovieEntry? movie) async =>
      _commit(await _loaded(), fileName, movie);

  /// Sets [fileName] to [movie] in [entries] at once, then saves.
  Future<void> _commit(
    Map<String, MovieEntry> entries,
    String fileName,
    MovieEntry? movie,
  ) async {
    final MovieEntry? before = entries[fileName];
    _set(entries, fileName, movie);
    try {
      await _save();
    } on StorageException {
      // Undo it, unless a later change to the same movie replaced it.
      if (identical(entries[fileName], movie)) {
        _set(entries, fileName, before);
      }
      rethrow;
    }
  }

  Future<Map<String, MovieEntry>> _loaded() => _loading ??= _read();

  /// The saved entries; none when there is no sidecar yet, or when it cannot be
  /// read.
  Future<Map<String, MovieEntry>> _read() async {
    try {
      return MovieIndexSidecar.decode(await File(_file).readAsString());
    } on PathNotFoundException {
      return <String, MovieEntry>{};
    } on FileSystemException catch (error, stackTrace) {
      await _moveAside(error, stackTrace);
    } on FormatException catch (error, stackTrace) {
      await _moveAside(error, stackTrace);
    }
    return <String, MovieEntry>{};
  }

  /// Renames an unreadable sidecar to `movies_v1.json.corrupt-<ms>` before
  /// anything is saved.
  Future<void> _moveAside(Object error, StackTrace stackTrace) async {
    final String aside =
        '$_file.corrupt-${_clock.now().millisecondsSinceEpoch}';
    try {
      await File(_file).rename(aside);
      _logger.warning(
        _tag,
        'Moved an unreadable movie index aside to ${aside.split('/').last}',
        error: error,
        stackTrace: stackTrace,
      );
    } on FileSystemException catch (moveError, moveStackTrace) {
      // Only an unwritable index folder refuses the rename, and it refuses
      // every save as well, so nothing can overwrite the sidecar.
      _logger.error(
        _tag,
        'Could not move an unreadable movie index aside ($error)',
        error: moveError,
        stackTrace: moveStackTrace,
      );
    }
  }

  /// Saves the entries as they are when this save's turn comes, so the last
  /// save always writes the newest state.
  Future<void> _save() {
    final Future<void> save = _saving.then((_) => _write());
    _saving = save.then((_) {}, onError: (Object _) {});
    return save;
  }

  /// Writes a temporary file and renames it over the sidecar, so a crash
  /// mid-write never leaves a truncated index (the titles live only here).
  Future<void> _write() async {
    final String json = MovieIndexSidecar.encode(await _loaded());
    try {
      await Directory(_paths.supportIndexDir).create(recursive: true);
      final File temp = await File(
        '$_file.tmp',
      ).writeAsString(json, flush: true);
      await temp.rename(_file);
    } on FileSystemException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not save the movie index',
        error: error,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(
        StorageException('Could not save the movie index', cause: error),
        stackTrace,
      );
    }
  }

  static void _set(
    Map<String, MovieEntry> entries,
    String fileName,
    MovieEntry? movie,
  ) {
    if (movie == null) {
      entries.remove(fileName);
    } else {
      entries[fileName] = movie;
    }
  }
}
