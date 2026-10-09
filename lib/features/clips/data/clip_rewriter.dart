import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/undo_token.dart';

/// Puts a remuxed copy of a clip in its place: what a privacy mark and a tags
/// edit share (`ClipPrivacy`, `ClipTags`).
///
/// [replaceWith] reads the clip's stamp and cached facts, has [remux] make the
/// new file in private scratch, and has `MediaPublisher.replace` put it in
/// the clip's place (the old clip stays, or is put back, when the gallery
/// refuses). The repository, the metadata cache ([patchMeta]) and the
/// thumbnails (`ThumbnailRepository.carryOver`) then follow the new version.
///
/// Throws what [remux] throws (`VideoProcessingException`) and
/// [MediaStoreException] when the gallery refused the new file; the clip is
/// then as it was. Not final so tests can fake it.
class ClipRewriter {
  ClipRewriter({
    required this._publisher,
    required this._repository,
    required this._metadata,
    required this._thumbnails,
    required this._paths,
  });

  final MediaPublisher _publisher;
  final ClipRepository _repository;
  final ClipMetadataCache _metadata;
  final ThumbnailRepository _thumbnails;
  final AppPaths _paths;

  /// Replaces [clip] with the file [remux] writes from its absolute path,
  /// its cached facts patched by [patchMeta].
  Future<void> replaceWith(
    ClipRef clip, {
    required Future<String> Function(String clipPath) remux,
    required ClipMeta Function(ClipMeta meta) patchMeta,
  }) async {
    final String path = _pathOf(clip);
    final FileStamp? before = await _stampOf(clip);
    final ClipMeta? meta = before == null
        ? null
        : _metadata.lookup(relPath: clip.relPath, stamp: before);
    final String remuxed = await remux(path);
    final UndoToken? replaced = await _publisher.replace(
      tempPath: remuxed,
      relPath: clip.relPath,
    );
    if (replaced == null) {
      throw MediaStoreException('Could not replace ${clip.relPath}');
    }
    await _repository.clipReplaced(clip);
    final FileStamp? after = await _stampOf(clip);
    if (after != null) {
      if (meta != null) {
        await _metadata.write(
          relPath: clip.relPath,
          stamp: after,
          meta: patchMeta(meta),
        );
      }
      if (before != null) {
        await _thumbnails.carryOver(clip, from: before, to: after);
      }
    }
    await _publisher.purge(replaced);
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
