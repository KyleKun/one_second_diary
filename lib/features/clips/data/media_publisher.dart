import 'dart:io';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/media_store_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/features/clips/data/clip_trash.dart';
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/clips/domain/undo_token.dart';

/// Every write the app makes into the public gallery folder (clips and
/// movies), in the order that never loses a user's file.
///
/// - [publish] moves a finished render into the gallery. The temp takes the
///   destination's file name first (Android's media store publishes under
///   the temp file's name), the destination folder is created first (a
///   deleted profile folder does not break saving), and the album is named
///   on every call, derived from the destination;
/// - [replace] backs the old clip up into `AppPaths.trashDir` (a copy: the
///   clip stays where it is), then publishes the new one over it; if that
///   fails the old clip is kept, or put back from the backup when the
///   platform had already removed it;
/// - [delete] backs the clip up, then deletes it through the gateway;
/// - [publishFromOriginal] moves a foreign video beside the diary
///   ([OriginalsStore], never the trash) and publishes its processed render
///   under the day name; if the move is refused nothing is published, and
///   if the publish fails the original comes back;
/// - every write returns an [UndoToken] for the snackbar: [undo] reverts
///   it, [purge] forgets its backup when the snackbar goes away, and
///   [purgeTrash] empties the trash at the next launch.
///
/// A clip's kept original recording travels with the clip: a publish or
/// replace given a [publish] `sourcePath` MOVES that camera temp into the
/// Originals folder under the clip's name once the clip landed (a same-volume
/// rename; the temp is consumed only then). A replace that puts ANOTHER
/// recording in the clip's place (`keepExistingSource: false`) backs the old
/// source up into the same trash entry and removes it, while an in-place
/// rewrite (privacy, tags, subtitle, mute) or a render from the clip's own
/// source ("Edit again") leaves it where it is, the default. A delete backs
/// the source up with the clip and removes it (one that cannot be backed up
/// stays, logged: never lost). Undo brings both back, or removes both;
/// [purgeTrash] puts an unfinished write's source back too. Without an
/// [OriginalsStore] nothing is kept.
///
/// A publish consumes its temp: moved into the gallery on success, deleted
/// on failure (the caller renders again). It succeeds only when the file is
/// then at its destination with the temp's size; a gateway `true` alone is
/// not trusted (see `_landed`). Nothing here throws: failures are logged
/// under the `[MediaGallery]` prefix and reported as null or false. An
/// invalid `relPath` is a caller bug and throws [ArgumentError].
///
/// Kept a plain class (not final) so tests of the save flows can fake it.
class MediaPublisher {
  MediaPublisher({
    required this._gateway,
    required this._paths,
    required this._logger,
    required Clock clock,
    OriginalsStore? originals,
  }) : _trash = ClipTrash(paths: _paths, logger: _logger, clock: clock),
       _originals = originals; // ignore: prefer_initializing_formals

  final MediaStoreGateway _gateway;
  final AppPaths _paths;
  final AppLogger _logger;
  final ClipTrash _trash;

  /// Where kept originals go (processed imports' and recordings'); null
  /// when the app has no Originals folder (then [publishFromOriginal]
  /// refuses and no source is kept).
  final OriginalsStore? _originals;

  static const String _tag = 'MediaGallery';

  /// Where the original of the clip at [relPath] is kept, relative to the
  /// Originals folder; null when it has none (or nothing is kept).
  String? originalRelPathOf(String relPath) =>
      _originals?.originalRelPathOf(relPath);

  /// The absolute path of the original of the clip at [relPath]; null
  /// when it has none.
  String? sourcePathOf(String relPath) => _originals?.sourcePathOf(relPath);

  /// Moves the finished file at [tempPath] into the gallery as [relPath]
  /// (relative to `AppPaths.videos`), replacing any file with that name,
  /// then keeps the recording at [sourcePath] as its original when one is
  /// given. Returns a token whose Undo deletes it again (and the source);
  /// null when it could not be published (the temp is deleted; the source
  /// is left where it was).
  Future<UndoToken?> publish({
    required String tempPath,
    required String relPath,
    String? sourcePath,
  }) async {
    if (!await _publish(tempPath: tempPath, relPath: relPath)) return null;
    return PublishedUndo(
      relPath: relPath,
      keptSourceRelPath: await _keep(sourcePath, relPath),
    );
  }

  /// Replaces the clip at [relPath] with the finished file at [tempPath],
  /// keeping the old clip in the trash for Undo. With [keepExistingSource]
  /// (the default: an in-place rewrite, or a clip rendered from its own
  /// source) the clip's source stays where it is; without it, another
  /// recording takes the clip's place: the old source goes into the same
  /// trash entry and the recording at [sourcePath], when given, is kept as
  /// the new clip's source. Returns null when nothing changed: no backup
  /// could be made (then nothing is published), or the publish failed (the
  /// old clip is kept or put back).
  Future<UndoToken?> replace({
    required String tempPath,
    required String relPath,
    String? sourcePath,
    bool keepExistingSource = true,
  }) async {
    final String? trashId = await _trash.backUp(relPath);
    if (trashId == null) {
      await _deleteQuietly(tempPath);
      return null;
    }
    final String? oldSource = keepExistingSource
        ? null
        : originalRelPathOf(relPath);
    final bool oldSourceBackedUp =
        oldSource != null && await _backUpSource(trashId, oldSource);
    if (await _publish(tempPath: tempPath, relPath: relPath)) {
      String? kept;
      if (oldSource != null && !oldSourceBackedUp) {
        _logger.warning(
          _tag,
          'The old original of $relPath stays: it could not be backed up',
        );
      } else {
        if (oldSource != null) await _originals?.remove(oldSource);
        kept = await _keep(sourcePath, relPath);
      }
      await _trash.commit(trashId);
      return ReplacedUndo(
        relPath: relPath,
        trashId: trashId,
        keptSourceRelPath: kept,
      );
    }
    // Android's media store deletes the old row before its insert, so a
    // failed publish may have taken the old clip with it.
    if (await File(_paths.absoluteFromVideos(relPath)).exists() ||
        await _restore(trashId, relPath)) {
      await _trash.drop(trashId);
    }
    return null;
  }

  /// Deletes the clip at [relPath], keeping it, and its source, in the
  /// trash for Undo. Returns null when the gateway refused (the clip is
  /// still there, e.g. Android asked for consent). When the trash has no
  /// room for a backup the clip is still deleted, without Undo
  /// ([UndoToken.canUndo]): a full phone is exactly when users delete
  /// clips; its source then stays where it is (logged), never deleted
  /// without a way back.
  Future<UndoToken?> delete(String relPath) async {
    final String? trashId = await _trash.backUp(relPath);
    final String? source = originalRelPathOf(relPath);
    final bool sourceBackedUp =
        trashId != null &&
        source != null &&
        await _backUpSource(trashId, source);
    if (!await _deleteFromGallery(relPath)) {
      if (trashId != null) await _trash.drop(trashId);
      return null;
    }
    if (source != null) {
      if (sourceBackedUp) {
        await _originals?.remove(source);
      } else {
        _logger.warning(
          _tag,
          'The original of $relPath stays: it could not be backed up',
        );
      }
    }
    if (trashId != null) await _trash.commit(trashId);
    return DeletedUndo(relPath: relPath, trashId: trashId);
  }

  /// Processes the foreign video at [sourceRelPath]: moves it beside the
  /// diary first (so nothing is ever lost), then publishes the render at
  /// [tempPath] as [relPath]. Returns null when the move was refused or
  /// failed (the original stays where it was, the temp is deleted, nothing
  /// is published) or when the publish failed (the original is put back).
  Future<UndoToken?> publishFromOriginal({
    required String tempPath,
    required String sourceRelPath,
    required String relPath,
  }) async {
    final OriginalsStore? originals = _originals;
    if (originals == null) {
      _logger.error(_tag, 'No Originals folder to move $sourceRelPath into');
      await _deleteQuietly(tempPath);
      return null;
    }
    // Kept under the processed clip's name (its own extension), so the
    // original stays this clip's source by name even when the render took
    // the day's next ordinal rather than the file's own stem.
    final String? kept = await originals.moveIn(
      sourceRelPath,
      as: OriginalsStore.originalRelPathFor(
        relPath,
        sourceName: PathNames.fileNameOf(sourceRelPath),
      ),
    );
    if (kept == null) {
      await _deleteQuietly(tempPath);
      return null;
    }
    if (await _publish(tempPath: tempPath, relPath: relPath)) {
      return OriginalMovedUndo(
        relPath: relPath,
        originalRelPath: kept,
        sourceRelPath: sourceRelPath,
      );
    }
    await originals.moveBack(originalRelPath: kept, relPath: sourceRelPath);
    return null;
  }

  /// Deletes the file at [relPath] for good, with no backup and no Undo.
  /// For movies: My movies asks before deleting, and backing up a movie of
  /// a gigabyte would double it on a phone that is likely full.
  /// False (logged) when the gateway refused; the file then stays.
  Future<bool> deleteWithoutUndo(String relPath) => _deleteFromGallery(relPath);

  /// Reverts the write of [token]: deletes a published file, or puts a
  /// replaced or deleted clip back, its source with it. False (logged)
  /// when it could not: the backup was purged, the gateway refused (the
  /// backup is kept, so Undo can be tried again), or a new clip took the
  /// deleted clip's name.
  Future<bool> undo(UndoToken token) async {
    switch (token) {
      case PublishedUndo(
        :final String relPath,
        :final String? keptSourceRelPath,
      ):
        if (!await _deleteFromGallery(relPath)) return false;
        if (keptSourceRelPath != null) {
          await _originals?.remove(keptSourceRelPath);
        }
        return true;
      case DeletedUndo(trashId: null):
        return false;
      case ReplacedUndo(
        :final String relPath,
        :final String trashId,
        :final String? keptSourceRelPath,
      ):
        return _restoreEntry(trashId, relPath, newSource: keptSourceRelPath);
      case OriginalMovedUndo(
        :final String relPath,
        :final String originalRelPath,
        :final String sourceRelPath,
      ):
        final OriginalsStore? originals = _originals;
        if (originals == null || !await _deleteFromGallery(relPath)) {
          return false;
        }
        return originals.moveBack(
          originalRelPath: originalRelPath,
          relPath: sourceRelPath,
        );
      case DeletedUndo(:final String relPath, trashId: final String trashId):
        if (await File(_paths.absoluteFromVideos(relPath)).exists()) {
          _logger.warning(
            _tag,
            'Did not undo the delete of $relPath: a new clip has that name',
          );
          return false;
        }
        return _restoreEntry(trashId, relPath);
    }
  }

  /// Forgets the backup of [token]: its Undo is no longer offered.
  Future<void> purge(UndoToken token) async {
    switch (token) {
      case PublishedUndo():
      case OriginalMovedUndo():
      case DeletedUndo(trashId: null):
        return;
      case ReplacedUndo(:final String trashId):
      case DeletedUndo(trashId: final String trashId):
        await _trash.drop(trashId);
    }
  }

  /// Empties the trash left by the previous session. Call it once at
  /// launch, before any write. A backup whose write never finished (the app
  /// died mid-replace) is put back where its clip is missing instead, and
  /// so is its source; one that cannot be put back is kept for the next
  /// launch.
  Future<void> purgeTrash() async {
    for (final String trashId in await _trash.pendingEntries()) {
      bool recovered = true;
      for (final String relPath in await _trash.relPathsIn(trashId)) {
        if (!await File(_paths.absoluteFromVideos(relPath)).exists() &&
            !await _restore(trashId, relPath)) {
          recovered = false;
        }
      }
      for (final String source in await _trash.sourcesIn(trashId)) {
        final OriginalsStore? originals = _originals;
        if (originals == null) continue;
        if (!await File(originals.absoluteOf(source)).exists() &&
            !await _restoreSource(trashId, source)) {
          recovered = false;
        }
      }
      if (recovered) await _trash.drop(trashId);
    }
  }

  /// The plain publish of [tempPath] as [relPath]: true once the file is
  /// at its destination; false (logged) with the temp deleted.
  Future<bool> _publish({
    required String tempPath,
    required String relPath,
  }) async {
    final String destination = _paths.absoluteFromVideos(relPath);
    final String album = _paths.albumFor(destination);
    String named = tempPath;
    try {
      named = await _nameLike(tempPath, destination);
      await File(destination).parent.create(recursive: true);
      final int size = await File(named).length();
      if (await _gateway.publish(tempFilePath: named, album: album) &&
          await _landed(destination, size: size)) {
        return true;
      }
      _logger.error(_tag, 'Could not publish $relPath into $album');
    } on Exception catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not publish $relPath into $album',
        error: error,
        stackTrace: stackTrace,
      );
    }
    await _deleteQuietly(named);
    return false;
  }

  /// Keeps the recording at [sourcePath] as the source of the clip at
  /// [relPath]; null when none is given, nothing is kept, or the store
  /// could not (logged there: the temp then stays for its owner).
  Future<String?> _keep(String? sourcePath, String relPath) async {
    final OriginalsStore? originals = _originals;
    if (sourcePath == null || originals == null) return null;
    return originals.keepSource(tempPath: sourcePath, relPath: relPath);
  }

  /// Backs the original kept at [originalRelPath] up into entry [trashId].
  Future<bool> _backUpSource(String trashId, String originalRelPath) async {
    final OriginalsStore? originals = _originals;
    if (originals == null) return false;
    return _trash.backUpSource(
      id: trashId,
      originalRelPath: originalRelPath,
      from: originals.absoluteOf(originalRelPath),
    );
  }

  /// Deletes [relPath] through the gateway; false (logged) when refused.
  Future<bool> _deleteFromGallery(String relPath) async {
    final String clip = _paths.absoluteFromVideos(relPath);
    final String album = _paths.albumFor(clip);
    try {
      if (await _gateway.delete(absolutePath: clip, album: album)) return true;
      _logger.error(_tag, 'Could not delete $relPath from $album');
    } on Exception catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not delete $relPath from $album',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return false;
  }

  /// Puts the clip of entry [trashId] back at [relPath], then the entry's
  /// sources, after removing the source kept for the clip being undone
  /// ([newSource]); the entry is dropped once the clip is back. False
  /// when the clip could not be restored (the entry is kept).
  Future<bool> _restoreEntry(
    String trashId,
    String relPath, {
    String? newSource,
  }) async {
    if (!await _restore(trashId, relPath)) return false;
    if (newSource != null) await _originals?.remove(newSource);
    for (final String source in await _trash.sourcesIn(trashId)) {
      await _restoreSource(trashId, source);
    }
    await _trash.drop(trashId);
    return true;
  }

  /// Publishes the backup of [relPath] in trash entry [trashId] back to
  /// where it came from, replacing whatever is there now. False (logged)
  /// when there is no such backup or the gateway refused.
  Future<bool> _restore(String trashId, String relPath) async {
    final String album = _paths.albumFor(_paths.absoluteFromVideos(relPath));
    try {
      final String? backup = await _trash.backupOf(
        id: trashId,
        relPath: relPath,
      );
      if (backup != null) {
        final int size = await File(backup).length();
        if (await _gateway.publish(tempFilePath: backup, album: album) &&
            await _landed(_paths.absoluteFromVideos(relPath), size: size)) {
          _logger.info(_tag, 'Restored $relPath from the trash');
          return true;
        }
      }
      _logger.error(_tag, 'Could not restore $relPath from the trash');
    } on Exception catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not restore $relPath from the trash',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return false;
  }

  /// Puts the original backed up in entry [trashId] back into the
  /// Originals folder at [originalRelPath]. False (logged) when it could
  /// not.
  Future<bool> _restoreSource(String trashId, String originalRelPath) async {
    final OriginalsStore? originals = _originals;
    final String? backup = await _trash.sourceBackupOf(
      id: trashId,
      originalRelPath: originalRelPath,
    );
    if (originals == null || backup == null) {
      _logger.error(
        _tag,
        'Could not restore the original $originalRelPath from the trash',
      );
      return false;
    }
    return originals.restore(
      backupPath: backup,
      originalRelPath: originalRelPath,
    );
  }

  /// Whether a publish the gateway reported done really put a file of
  /// [size] bytes at [destination]. `media_store_plus` may answer true with
  /// the file elsewhere: from Android 10 an insert whose name exists on disk
  /// without a MediaStore row (a clip an older install wrote by path) gets a
  /// unique name, `… (1).mp4`. The diary would keep showing the old clip, so
  /// that is a failure.
  Future<bool> _landed(String destination, {required int size}) async {
    try {
      if (await File(destination).length() == size) return true;
    } on FileSystemException {
      // Missing: fall through.
    }
    _logger.error(
      _tag,
      'The media store reported a publish, but '
      '${_paths.relativeToVideos(destination)} is not at its destination '
      'with $size bytes; the file may sit under another name',
    );
    return false;
  }

  /// Deletes [path] if it is there; a failure is only logged.
  Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on PathNotFoundException {
      // Already gone.
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not delete $path',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// [tempPath], renamed in its folder to [destination]'s file name.
  static Future<String> _nameLike(String tempPath, String destination) async {
    final String name = PathNames.fileNameOf(destination);
    if (PathNames.fileNameOf(tempPath) == name) return tempPath;
    final File renamed = await File(
      tempPath,
    ).rename('${tempPath.substring(0, tempPath.lastIndexOf('/'))}/$name');
    return renamed.path;
  }
}
