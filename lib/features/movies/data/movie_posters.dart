import 'dart:io';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/thumbnail_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_queue.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_ticket.dart';
import 'package:one_second_diary/features/clips/domain/thumbnail_tier.dart';

/// The posters of My movies: each movie's first frame, made once per version of
/// its file and kept in `AppPaths.thumbsDir/movies/` (the OS cache folder,
/// beside the clips' thumbnails but never listed with them).
class MoviePosters {
  MoviePosters({
    required this._gateway,
    required this._queue,
    required this._paths,
    required this._logger,
  });

  final ThumbnailGateway _gateway;
  final ThumbnailQueue _queue;
  final AppPaths _paths;
  final AppLogger _logger;

  static const String _tag = 'THUMBNAILS';

  /// The last poster made or found, by movie and shape.
  final Map<(String, VideoOrientation), String> _made =
      <(String, VideoOrientation), String>{};

  /// The poster of the movie at [file] (its path in `Movies/`) in its
  /// [orientation] (landscape while unknown) if this session has made or found
  /// it; null otherwise (use [request]).
  String? cachedFile(String file, {VideoOrientation? orientation}) =>
      _made[_keyOf(file, orientation)];

  /// Asks for the poster of the movie at [file] in its [orientation]: served
  /// from disk when it exists, made otherwise.
  ThumbnailTicket request(String file, {VideoOrientation? orientation}) {
    final (String, VideoOrientation) key = _keyOf(file, orientation);
    // Keyed apart from the clips' thumbnails (their output paths).
    return _queue.request((MoviePosters, key), () => _make(key));
  }

  static (String, VideoOrientation) _keyOf(
    String file,
    VideoOrientation? orientation,
  ) => (file, orientation ?? VideoOrientation.landscape);

  Future<String?> _make((String, VideoOrientation) key) async {
    final (String relPath, VideoOrientation orientation) = key;
    final String video = '${_paths.movies}$relPath';
    String? poster;
    try {
      final FileStat stat = await File(video).stat();
      if (stat.type == FileSystemEntityType.notFound) {
        _logger.warning(_tag, 'No poster for $relPath: the movie is gone');
        return null;
      }
      final ({int width, int height}) bounds = switch (orientation) {
        VideoOrientation.landscape => ThumbnailTier.poster.boundsFor(
          width: 1920,
          height: 1080,
        ),
        VideoOrientation.portrait => ThumbnailTier.poster.boundsFor(
          width: 1080,
          height: 1920,
        ),
      };
      final String output =
          '${_paths.thumbsDir}/movies/${_hash(relPath)}_'
          '${stat.modified.millisecondsSinceEpoch}_${stat.size}_'
          '${bounds.width}x${bounds.height}.jpg';
      if (await File(output).exists()) {
        poster = output;
      } else {
        poster = await _gateway.writeThumbnail(
          videoPath: video,
          outputPath: output,
          maxWidth: bounds.width,
          maxHeight: bounds.height,
          quality: 75,
          timeMs: 0,
        );
        if (poster == null) {
          _logger.warning(_tag, 'Could not make the poster of $relPath');
        }
      }
    } on Exception catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not make the poster of $relPath',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (poster != null) _made[key] = poster;
    return poster;
  }

  /// 64-bit FNV-1a of [text], as 16 hex digits.
  static String _hash(String text) {
    int hash = 0xcbf29ce484222325;
    for (final int unit in text.codeUnits) {
      hash = (hash ^ unit) * 0x100000001b3;
    }
    final String high = ((hash >> 32) & 0xffffffff).toRadixString(16);
    final String low = (hash & 0xffffffff).toRadixString(16);
    return '${high.padLeft(8, '0')}${low.padLeft(8, '0')}';
  }
}
