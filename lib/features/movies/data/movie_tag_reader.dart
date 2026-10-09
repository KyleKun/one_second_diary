import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/movies/data/movie_index.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/domain/movie_tags.dart';

/// Reads what a movie file says about itself (its MP4 tags).
abstract interface class MovieTagSource {
  /// The tags of the movie at the absolute [path]. Throws what the probe
  /// throws (a `VideoProcessingException` for a file ffprobe can't read).
  Future<MovieTags> tagsOf(String path);
}

/// [MovieTagSource] through the media engine's ffprobe (one queued job per
/// movie, behind at most one probe of the metadata backfill): the title, the
/// profile, the clips, days, tag filter, transition and music (`description`,
/// written by the movie join; older movies lack it), the duration, the canvas
/// and the chapters.
final class EngineMovieTagSource implements MovieTagSource {
  EngineMovieTagSource({required this._engine});

  final MediaEngine _engine;

  @override
  Future<MovieTags> tagsOf(String path) async {
    final ClipProbe probe = await _engine.probe(path);
    return MovieTags(
      title: probe.title,
      comment: probe.comment,
      description: probe.description,
      durationMs: probe.durationMs,
      width: probe.width,
      height: probe.height,
      chapters: probe.chapters,
    );
  }
}

/// My movies reads, once, the tags of each movie the movie index knows nothing
/// about (made by an older install, copied in, or made before a reinstall lost
/// the index while Android kept `DCIM/…/Movies`), and records what they say, so
/// titles, profiles, counts, days and chapters survive a reinstall.
class MovieTagReader {
  MovieTagReader({
    required this._source,
    required this._index,
    required this._paths,
    required this._logger,
  });

  final MovieTagSource _source;
  final MovieIndex _index;
  final AppPaths _paths;
  final AppLogger _logger;

  static const String _tag = 'MOVIES';

  /// [movie], listed from its file alone, as its tags describe it.
  Future<MovieEntry> read(MovieEntry movie) async {
    final MovieTags tags;
    try {
      tags = await _source.tagsOf('${_paths.movies}${movie.fileName}');
    } on AppException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not read the tags of ${movie.fileName}',
        error: error,
        stackTrace: stackTrace,
      );
      return movie;
    }
    final MovieEntry described = MovieEntry(
      fileName: movie.fileName,
      title: tags.title ?? movie.title,
      profile: tags.profile,
      clipCount: tags.clipCount,
      from: tags.from,
      to: tags.to,
      createdAt: movie.createdAt,
      durationMs: tags.durationMs,
      orientation: tags.orientation,
      privateClipCount: tags.privateClipCount,
      tags: tags.tags,
      without: tags.without,
      chapters: tags.chapters,
      transition: tags.transition,
      musicOn: tags.musicOn,
    );
    try {
      return await _index.putIfAbsent(described);
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not record the tags of ${movie.fileName}',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return described;
  }
}
