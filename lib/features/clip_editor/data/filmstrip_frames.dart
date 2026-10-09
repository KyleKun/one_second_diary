import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/thumbnail_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

/// One frame of the filmstrip: tile [index] and the JPEG it shows.
final class FilmstripFrame extends Equatable {
  const FilmstripFrame({required this.index, required this.path});

  final int index;
  final String path;

  @override
  List<Object?> get props => <Object?>[index, path];
}

/// The frames under the trim window, made from the source the editor opened (a camera temp or a pick, never a saved clip).
/// Kept in `filmstrip/` of the OS cache until [dispose]; one editor exists at a time, so it also clears what a killed editor left.
/// Failures are logged and skipped (the tile keeps its placeholder); nothing throws. Not final so page tests can fake it.
class FilmstripFrames {
  FilmstripFrames({
    required this._gateway,
    required this._paths,
    required this._logger,
  });

  final ThumbnailGateway _gateway;
  final AppPaths _paths;
  final AppLogger _logger;

  static const String _tag = 'SAVE';

  /// The JPEG quality of the clip thumbnails (`ThumbnailRepository`).
  static const int _quality = 75;

  String get _folder => '${_paths.cacheDir}/filmstrip';

  /// How many tiles the strip makes for a source of [durationMs]: [fitted] (fills the strip) under [perSecondFromMs], then one a second, at most [maxTiles].
  static int tileCount({required int durationMs, required int fitted}) =>
      durationMs < perSecondFromMs
      ? fitted
      : (durationMs / 1000).round().clamp(perSecondFromMs ~/ 1000, maxTiles);

  /// The source length from which the strip makes a tile a second.
  static const int perSecondFromMs = 10000;

  /// The most tiles a strip makes (a 60 s source).
  static const int maxTiles = 60;

  /// [count] frames spread evenly over [durationMs] of the video at [path], each from the middle of its tile, at most [width] × [height]
  /// (give the video's aspect ratio: Android 8.0 stretches a frame to the bounds): the tiles in [order], or all left to right.
  /// Each is reported once written; cancelling the subscription stops the frames not started yet.
  Stream<FilmstripFrame> of(
    String path, {
    required int durationMs,
    required int count,
    required int width,
    required int height,
    Iterable<int>? order,
  }) async* {
    final String source = _sourceOf(path);
    for (final int index in order ?? Iterable<int>.generate(count)) {
      final int timeMs = (durationMs * (2 * index + 1) / (2 * count)).round();
      final String? written = await _gateway.writeThumbnail(
        videoPath: path,
        outputPath: '$_folder/${source}_${count}_$index.jpg',
        maxWidth: width,
        maxHeight: height,
        quality: _quality,
        timeMs: timeMs,
      );
      if (written == null) {
        _logger.warning(_tag, 'Could not make filmstrip frame $index of $path');
        continue;
      }
      yield FilmstripFrame(index: index, path: written);
    }
  }

  /// One frame of the video at [path], [timeMs] in, at most [width] ×
  /// [height] pixels; null when it can't be made (logged).
  Future<String?> frameAt(
    String path, {
    required int timeMs,
    required int width,
    required int height,
  }) async {
    final String written =
        '$_folder/${_sourceOf(path)}_at_${timeMs}_${width}x$height.jpg';
    final String? frame = await _gateway.writeThumbnail(
      videoPath: path,
      outputPath: written,
      maxWidth: width,
      maxHeight: height,
      quality: _quality,
      timeMs: timeMs,
    );
    if (frame == null) {
      _logger.warning(_tag, 'Could not make the frame at $timeMs ms of $path');
    }
    return frame;
  }

  static String _sourceOf(String path) =>
      path.hashCode.toUnsigned(32).toRadixString(16);

  /// Deletes every frame made. Never throws.
  Future<void> dispose() async {
    try {
      final Directory folder = Directory(_folder);
      if (await folder.exists()) await folder.delete(recursive: true);
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not delete the filmstrip frames',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
