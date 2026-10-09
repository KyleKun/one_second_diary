import 'dart:async';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_rewriter.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';

/// Marks a saved clip private or public. A private clip is left out of movies
/// unless the user includes it, and is blurred where clips are browsed. The
/// mark is a tag in its file (`ClipPrivacyTag`); the library
/// (`ClipIndex.isPrivate`) and the metadata cache only mirror it.
///
/// [setPrivate] tells the library first, so every screen shows the change at
/// once, then rewrites the file through [ClipRewriter]. When the rewrite
/// fails the library shows the clip as it was.
///
/// A clip's kept original carries the same tag: once the clip is rewritten its
/// source is remuxed the same way and put back ([OriginalsStore]), so nothing
/// that reads the folder later can take it for public. A source that could
/// not be rewritten is logged; the clip's own mark stands. Not final so tests
/// can fake it.
class ClipPrivacy {
  ClipPrivacy({
    required this._engine,
    required MediaPublisher publisher,
    required ClipRepository repository,
    required ClipMetadataCache metadata,
    required ThumbnailRepository thumbnails,
    required AppPaths paths,
    required this._logger,
    OriginalsStore? originals,
  }) : _originals = originals, // ignore: prefer_initializing_formals
       _repository = repository,
       _rewriter = ClipRewriter(
         publisher: publisher,
         repository: repository,
         metadata: metadata,
         thumbnails: thumbnails,
         paths: paths,
       );

  final MediaEngine _engine;
  final ClipRepository _repository;
  final ClipRewriter _rewriter;
  final AppLogger _logger;

  /// Where a clip's kept original is; null when nothing is kept.
  final OriginalsStore? _originals;

  static const String _tag = 'PRIVACY';

  /// The end of the last write asked for each clip, by relPath: a clip's
  /// writes run one after the other, so two taps never rewrite one file at
  /// once.
  final Map<String, Completer<void>> _writes = <String, Completer<void>>{};

  /// Whether [clip] is private, as the library knows it.
  bool isPrivate(ClipRef clip) =>
      _repository.snapshotOf(clip.profile)?.isPrivate(clip) ?? false;

  /// Marks [clip] private, or public; nothing to do when it already is.
  ///
  /// Throws `VideoProcessingException` when the remux failed and
  /// [MediaStoreException] when the gallery refused the new file; the clip
  /// is then as it was.
  Future<void> setPrivate(ClipRef clip, {required bool private}) async {
    final Completer<void>? previous = _writes[clip.relPath];
    final Completer<void> done = Completer<void>();
    _writes[clip.relPath] = done;
    try {
      // Never fails: a failed write is told to its own caller only.
      await previous?.future;
      await _set(clip, private: private);
    } finally {
      if (identical(_writes[clip.relPath], done)) {
        _writes.remove(clip.relPath);
      }
      done.complete();
    }
  }

  Future<void> _set(ClipRef clip, {required bool private}) async {
    final bool was = isPrivate(clip);
    if (was == private) return;
    _repository.privacyKnown(clip.relPath, private: private);
    try {
      await _rewriter.replaceWith(
        clip,
        remux: (String path) =>
            _engine.remuxPrivacy(clipPath: path, private: private),
        patchMeta: (ClipMeta meta) => meta.withPrivacy(isPrivate: private),
      );
      _logger.info(
        _tag,
        'Marked ${clip.relPath} ${private ? 'private' : 'public'}',
      );
      await _markSource(clip, private: private);
    } on Object catch (error, stackTrace) {
      _repository.privacyKnown(clip.relPath, private: was);
      _logger.error(
        _tag,
        'Could not mark ${clip.relPath} ${private ? 'private' : 'public'}',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Remuxes [clip]'s kept original with the same mark, when it has one.
  /// Never throws: a source that could not be rewritten is logged.
  Future<void> _markSource(ClipRef clip, {required bool private}) async {
    final OriginalsStore? originals = _originals;
    final String? original = originals?.originalRelPathOf(clip.relPath);
    if (originals == null || original == null) return;
    try {
      final String remuxed = await _engine.remuxPrivacy(
        clipPath: originals.absoluteOf(original),
        private: private,
      );
      if (await originals.replaceWith(
        originalRelPath: original,
        tempPath: remuxed,
      )) {
        return;
      }
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not mark the original of ${clip.relPath} '
        '${private ? 'private' : 'public'}',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    _logger.warning(
      _tag,
      'Could not mark the original of ${clip.relPath} '
      '${private ? 'private' : 'public'}',
    );
  }
}
