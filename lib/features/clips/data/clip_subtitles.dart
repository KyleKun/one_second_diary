import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/undo_token.dart';

/// The subtitle of a saved clip: read for the subtitle sheet, rewritten when
/// the user saves it.
///
/// A clip's subtitle is its embedded `mov_text` stream; the metadata cache
/// only mirrors it.
/// - [textOf] answers from the `ClipMetadataCache`, and reads the file only
///   when the cache does not describe the clip as it is on disk;
/// - [rewrite] remuxes a copy (stream copy, tags kept, the text as one cue
///   over the whole clip; empty text removes the stream) and has
///   `MediaPublisher.replace` put it in the clip's place. The repository,
///   metadata cache and thumbnails follow, and the backup is dropped: a
///   subtitle save has no Undo.
///
/// Not final so tests can fake it.
class ClipSubtitles {
  ClipSubtitles({
    required this._engine,
    required this._publisher,
    required this._repository,
    required this._metadata,
    required this._thumbnails,
    required this._paths,
    required this._logger,
  });

  final MediaEngine _engine;
  final MediaPublisher _publisher;
  final ClipRepository _repository;
  final ClipMetadataCache _metadata;
  final ThumbnailRepository _thumbnails;
  final AppPaths _paths;
  final AppLogger _logger;

  static const String _tag = 'SUBTITLES';

  /// The subtitle text of [clip]; `''` when it has none.
  ///
  /// Throws `VideoProcessingException` when the file had to be read and
  /// ffmpeg gave no answer.
  Future<String> textOf(ClipRef clip) async {
    final FileStamp? stamp = await _stampOf(clip);
    final String? cached = stamp == null
        ? null
        : _metadata.lookup(relPath: clip.relPath, stamp: stamp)?.subtitleText;
    if (cached != null) return cached;
    try {
      return await _engine.readSubtitles(_pathOf(clip));
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not read the subtitles of ${clip.relPath}',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Makes [text] (trimmed) the subtitle of [clip]; empty text removes it.
  ///
  /// Throws `VideoProcessingException` when the remux failed and
  /// [MediaStoreException] when the gallery refused the new file; the clip
  /// is then as it was.
  Future<void> rewrite(ClipRef clip, String text) async {
    try {
      await _rewrite(clip, text.trim());
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not rewrite the subtitles of ${clip.relPath}',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _rewrite(ClipRef clip, String subtitle) async {
    final String path = _pathOf(clip);
    final FileStamp? before = await _stampOf(clip);
    final ClipMeta? meta = before == null
        ? null
        : _metadata.lookup(relPath: clip.relPath, stamp: before);
    final int durationMs =
        meta?.durationMs ?? (await _engine.probe(path)).durationMs ?? 0;
    final String remuxed = await _engine.remuxSubtitles(
      clipPath: path,
      text: subtitle,
      durationMs: durationMs,
    );
    final UndoToken? replaced = await _publisher.replace(
      tempPath: remuxed,
      relPath: clip.relPath,
    );
    if (replaced == null) {
      throw MediaStoreException(
        'Could not replace ${clip.relPath} with its new subtitles',
      );
    }
    await _repository.clipReplaced(clip);
    final FileStamp? after = await _stampOf(clip);
    if (after != null) {
      if (meta != null) {
        await _metadata.write(
          relPath: clip.relPath,
          stamp: after,
          meta: meta.withSubtitle(subtitle),
        );
      }
      if (before != null) {
        await _thumbnails.carryOver(clip, from: before, to: after);
      }
    }
    await _publisher.purge(replaced);
    _logger.info(
      _tag,
      subtitle.isEmpty
          ? 'Removed the subtitles of ${clip.relPath}'
          : 'Rewrote the subtitles of ${clip.relPath}',
    );
  }

  String _pathOf(ClipRef clip) => _paths.absoluteFromVideos(clip.relPath);

  /// The stamp the index holds for [clip], else the file's own; null when
  /// the file is gone.
  Future<FileStamp?> _stampOf(ClipRef clip) async {
    final FileStamp? indexed = _repository
        .snapshotOf(clip.profile)
        ?.stampOf(clip);
    if (indexed != null) return indexed;
    final FileStat stat = await FileStat.stat(_pathOf(clip));
    if (stat.type == FileSystemEntityType.notFound) return null;
    return FileStamp(
      sizeBytes: stat.size,
      modifiedMs: stat.modified.millisecondsSinceEpoch,
    );
  }
}
