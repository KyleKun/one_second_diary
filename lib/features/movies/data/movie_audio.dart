import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/domain/undo_token.dart';
import 'package:one_second_diary/features/movies/data/movie_repository.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/domain/movie_tags.dart';

/// Turns a movie's music off, or on again.
class MovieAudio {
  MovieAudio({
    required MediaEngine engine,
    required MediaPublisher publisher,
    required MovieRepository movies,
    required AppPaths paths,
    required AppLogger logger,
  }) : this._(engine, publisher, movies, paths, logger);

  MovieAudio._(
    this._engine,
    this._publisher,
    this._movies,
    this._paths,
    this._logger,
  );

  final MediaEngine _engine;
  final MediaPublisher _publisher;
  final MovieRepository _movies;
  final AppPaths _paths;
  final AppLogger _logger;

  static const String _tag = 'MOVIE AUDIO';

  /// [movie] with its music turned off when it plays, on when it does not;
  /// [movie] itself when it has no music.
  Future<MovieEntry> toggle(MovieEntry movie) async {
    if (movie.musicOn == null) return movie;
    final String path = '${_paths.movies}${movie.fileName}';
    final String relPath = '${PathNames.moviesFolder}/${movie.fileName}';
    final ClipProbe probe = await _engine.probe(path);
    final bool? playing =
        MovieTags(description: probe.description).musicOn ?? movie.musicOn;
    if (playing == null) return movie;
    final bool on = !playing;
    final String swapped = await _engine.swapMovieAudio(
      moviePath: path,
      description: MovieTags.withMusic(probe.description, on: on),
    );
    final UndoToken? replaced = await _publisher.replace(
      tempPath: swapped,
      relPath: relPath,
    );
    if (replaced == null) {
      throw MediaStoreException('Could not replace the movie $relPath');
    }
    await _publisher.purge(replaced);
    _logger.info(
      _tag,
      'Turned the music of ${movie.fileName} ${on ? 'on' : 'off'}',
    );
    final MovieEntry toggled = movie.withMusicOn(on: on);
    try {
      await _movies.update(toggled);
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Swapped the sound of ${movie.fileName} but could not save the index',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return toggled;
  }
}
