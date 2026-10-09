import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/clip_recipe.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/rendered_clip.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_meta_of_save.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/clip_write.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/thumbnail_tier.dart';
import 'package:one_second_diary/features/clips/domain/undo_token.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Saves, replaces and deletes day clips: the one place that turns a
/// finished render into a diary clip and keeps every cache in step.
///
/// A save, after the media engine rendered into scratch:
/// 1. names the clip. Adding takes the next ordinal of the day across the
///    whole profile (`yyyy-MM-dd.mp4`, then `-2`, `-3`, …) and never a name
///    already on disk; existing files are never renamed. Replacing keeps the
///    clip's name;
/// 2. publishes it through [MediaPublisher] (folder created first, explicit
///    album, the old version kept in the trash until Undo expires);
/// 3. patches the [ClipRepository] snapshot, writes the clip's facts to the
///    [ClipMetadataCache] (the save knows them all, so the backfill never
///    probes a new clip) and asks for both thumbnails while the file is hot;
/// 4. deletes the source file only when the app owns it (see
///    [ClipOwnership]) and it is not in the diary folder.
///
/// A foreign video processed into a clip ([saveProcessed], or a [save] that
/// replaces a clip with a render of that very file) never goes to the trash:
/// its original moves beside the diary first
/// (`MediaPublisher.publishFromOriginal`), and a refused move saves nothing.
/// The same road is taken when a [save] replaces a clip the app did not make
/// (`ClipIndex.isForeign`) with another recording or a gallery pick: the
/// user's file is moved beside the diary under the clip's name (` (2)` on a
/// clash), never trashed, and Undo brings it back from there; the clip's new
/// source (the camera temp) is released as usual, not kept, because the name
/// is the user's file's. A clip the app made keeps the trash road. A converted
/// clip ([saveAt]) is published under the name it was given, with the facts
/// the converter knows.
///
/// A recording's original is kept beside the diary when the save asks ([save]
/// `keepSource`, the "Keep original recordings" switch): the publisher moves
/// the camera temp there under the clip's name, the sidecar gets the save's
/// recipe, and the source is not released (it was consumed). "Edit again"
/// renders a clip from its own kept source (`ClipSource.owned` false): that
/// source stays where it is, still the clip's by name, and the sidecar gets
/// the new recipe. A source the editor does not own is never deleted here,
/// whatever its label.
///
/// A private clip stays private when it is replaced (the saver renders the
/// new one private) and when its delete is undone; a new clip never is.
/// A clip's tags likewise: the saver renders a replacement with them, and
/// an undone delete brings them back at once.
///
/// It returns a [ClipWrite] whose [undo] or [dismiss] the snackbar calls.
/// Failures throw [MediaStoreException] and leave the day as it was, with
/// the source kept so the user can try again.
///
/// What "Edit again" opens a clip on: its kept original, the recipe the
/// sidecar holds for it and the clip's cached origin (null when the facts
/// are not cached: a recording), which picks how the original is opened
/// and re-saved (`OriginalRenderFacts`; `ClipStore.editAgainOf`).
typedef EditAgainSource = ({
  String sourcePath,
  ClipRecipe? recipe,
  ClipOrigin? origin,
});

/// Kept a plain class (not final) so the save and Diary flows can fake it.
class ClipStore {
  ClipStore({
    required this._publisher,
    required this._repository,
    required this._metadata,
    required this._thumbnails,
    required this._paths,
    required this._logger,
    required this._isIOS,
  });

  final MediaPublisher _publisher;
  final ClipRepository _repository;
  final ClipMetadataCache _metadata;
  final ThumbnailRepository _thumbnails;
  final AppPaths _paths;
  final AppLogger _logger;

  /// `Platform.isIOS` in the app; injected so tests run either layout on
  /// any host.
  final bool _isIOS;

  static const String _tag = 'SAVE';

  /// The folder holding everything private to the app, where every camera,
  /// picker and export plugin writes its temps:
  /// - Android: `/data/user/0/<package>`, the parent of `internal`
  ///   (`app_flutter`) and of the `cache` folder the plugins use;
  /// - iOS: the app container, two levels above `internal`
  ///   (`Library/Application Support`), which also holds `Library/Caches`
  ///   and `tmp/` (camera and image picker outputs) and `Documents`.
  String get _appContainer {
    final List<String> segments = _paths.internal.split('/')
      ..length -= _isIOS ? 2 : 1;
    return segments.join('/');
  }

  /// Makes [rendered] (the engine's output for [request], made from
  /// [source]) the clip of [day] in [profile] that [mode] says. The render's
  /// file name does not matter: the store names the clip.
  ///
  /// With [keepSource], a recording the editor owns is kept as the clip's
  /// original instead of being deleted; a gallery pick or a photo is never
  /// copied.
  ///
  /// A [ReplaceClip] must name a clip of [profile] and [day] (an
  /// [ArgumentError] otherwise, before anything is written).
  Future<ClipWrite> save({
    required RenderedClip rendered,
    required ClipRenderRequest request,
    required ClipSource source,
    required ProfileKey profile,
    required LocalDay day,
    required ClipSaveMode mode,
    bool keepSource = false,
  }) async {
    if (mode case ReplaceClip(
      :final ClipRef clip,
    ) when clip.profile != profile || clip.day != day) {
      throw ArgumentError.value(
        clip,
        'mode',
        'replaces a clip that is not of ${profile.value}/${day.fileStem}',
      );
    }
    if (mode case ReplaceClip(:final ClipRef clip)) {
      final bool ownFile = await _isOwnFile(source, clip);
      if (ownFile || _isForeign(clip)) {
        // A foreign clip, processed from its own file or replaced by
        // another recording: the user's file goes beside the diary, not
        // to the trash.
        final ClipWrite? write = await saveProcessed(
          rendered: rendered,
          request: request,
          profile: profile,
          day: day,
          sourceRelPath: clip.relPath,
          clip: clip,
          renderedFromOriginal: ownFile,
        );
        if (write == null) {
          throw MediaStoreException(
            'Could not move the original of ${clip.relPath} aside',
          );
        }
        if (!ownFile) await _releaseSource(source);
        return write;
      }
    }
    // The recording to keep: the editor's own camera temp, when asked.
    final String? sourcePath =
        keepSource &&
            source is VideoSource &&
            source.fromRecording &&
            source.owned
        ? source.path
        : null;
    // "Edit again": the new clip was rendered from the clip's own kept
    // source, which stays its source by name.
    bool editsOwnSource = false;
    if (mode case ReplaceClip(:final ClipRef clip) when !source.owned) {
      editsOwnSource = await _isSourceOf(source, clip);
    }
    final ClipWrite write = switch (mode) {
      AddClip() => await _add(rendered, profile, day, sourcePath: sourcePath),
      ReplaceClip(:final ClipRef clip) => await _replace(
        rendered,
        clip,
        sourcePath: sourcePath,
        keepExistingSource: editsOwnSource,
      ),
    };
    final bool hasSource =
        write.undo.keptSourceRelPath != null || editsOwnSource;
    await _recordFacts(
      write.clip,
      meta: clipMetaOfSave(
        rendered: rendered,
        request: request,
        recipe: hasSource ? ClipRecipe.of(request) : null,
      ),
      orientation: request.orientation,
    );
    // A kept source was consumed by the publisher; any other goes by its
    // ownership.
    if (write.undo.keptSourceRelPath == null) await _releaseSource(source);
    return write;
  }

  /// What "Edit again" opens [clip] on: its kept original, the recipe its
  /// sidecar entry holds (null after a reinstall: the editor then opens with
  /// its defaults) and its cached origin, so a processed import is re-saved
  /// as one. Null when the clip has no source.
  EditAgainSource? editAgainOf(ClipRef clip) {
    final String? path = _publisher.sourcePathOf(clip.relPath);
    if (path == null) return null;
    final FileStamp? stamp = _repository
        .snapshotOf(clip.profile)
        ?.stampOf(clip);
    final ClipMeta? meta = stamp == null
        ? null
        : _metadata.lookup(relPath: clip.relPath, stamp: stamp);
    return (sourcePath: path, recipe: meta?.recipe, origin: meta?.origin);
  }

  /// Whether [source] is [clip]'s kept original, compared with links
  /// resolved.
  Future<bool> _isSourceOf(ClipSource source, ClipRef clip) async {
    final String? kept = _publisher.sourcePathOf(clip.relPath);
    if (kept == null) return false;
    try {
      return await File(source.path).resolveSymbolicLinks() ==
          await File(kept).resolveSymbolicLinks();
    } on FileSystemException {
      return false;
    }
  }

  /// Files [rendered] (the processed render of the foreign video at
  /// [sourceRelPath], made for [request]) as a clip of [day] in [profile]:
  /// the original moves beside the diary FIRST, then the render is
  /// published under the day name ([clip]'s own name when the video was an
  /// indexed clip, else the day's next free name) and its facts written
  /// from the render, so the clip is the app's own from then on. Null when
  /// the move was refused or failed: the original stays, the render is
  /// deleted, nothing changed. Throws [MediaStoreException] when the
  /// publish failed after the move (the original is put back).
  ///
  /// The sidecar gets [request]'s recipe only when the render was made
  /// from that original ([renderedFromOriginal], the default); a foreign
  /// clip replaced by another recording keeps the moved file beside the
  /// diary with no recipe (Edit again then opens it with the editor's
  /// defaults).
  Future<ClipWrite?> saveProcessed({
    required RenderedClip rendered,
    required ClipRenderRequest request,
    required ProfileKey profile,
    required LocalDay day,
    required String sourceRelPath,
    ClipRef? clip,
    bool renderedFromOriginal = true,
  }) async {
    final String relPath = clip?.relPath ?? await _freeName(profile, day);
    final UndoToken? undo = await _publisher.publishFromOriginal(
      tempPath: rendered.tempPath,
      sourceRelPath: sourceRelPath,
      relPath: relPath,
    );
    if (undo == null) {
      if (clip != null &&
          !await File(_paths.absoluteFromVideos(clip.relPath)).exists()) {
        // Moved aside, but nothing took its place and it did not come back.
        await _forget(clip);
        throw MediaStoreException('Could not process ${clip.relPath}');
      }
      return null;
    }
    final ClipRef written = ClipRef(profile: profile, relPath: relPath);
    if (clip != null) _metadata.remove(clip.relPath);
    await _repository.clipAdded(written);
    await _recordFacts(
      written,
      // The original moved beside the diary is the clip's source now.
      meta: clipMetaOfSave(
        rendered: rendered,
        request: request,
        recipe: renderedFromOriginal ? ClipRecipe.of(request) : null,
      ),
      orientation: request.orientation,
    );
    return ClipWrite(clip: written, undo: undo);
  }

  /// Publishes [rendered] (in [format]) as the clip at [relPath], a name
  /// the caller chose (a converted profile's mirrored clip), with
  /// [meta] as its facts. Throws [MediaStoreException] when the gallery
  /// refused.
  Future<ClipWrite> saveAt({
    required RenderedClip rendered,
    required ClipFormat format,
    required ClipRef clip,
    required ClipMeta meta,
  }) async {
    final UndoToken? undo = await _publisher.publish(
      tempPath: rendered.tempPath,
      relPath: clip.relPath,
    );
    if (undo == null) {
      throw MediaStoreException('Could not save the clip ${clip.relPath}');
    }
    await _repository.clipAdded(clip);
    await _recordFacts(clip, meta: meta, orientation: format.orientation);
    return ClipWrite(clip: clip, undo: undo);
  }

  /// Writes [clip]'s facts through to the cache and asks for its
  /// thumbnails while the file is hot.
  Future<void> _recordFacts(
    ClipRef clip, {
    required ClipMeta meta,
    required VideoOrientation orientation,
  }) async {
    final FileStamp? stamp = _repository
        .snapshotOf(clip.profile)
        ?.stampOf(clip);
    if (stamp == null) return;
    await _metadata.write(relPath: clip.relPath, stamp: stamp, meta: meta);
    for (final ThumbnailTier tier in ThumbnailTier.values) {
      _thumbnails.request(
        clip,
        stamp: stamp,
        tier: tier,
        orientation: orientation,
      );
    }
  }

  /// Whether [clip] is one the app did not make (badged "Imported"): as
  /// the library knows it, or as its cached facts say (`ClipSchema.other`)
  /// when the library has not been told yet.
  bool _isForeign(ClipRef clip) {
    final ClipIndex? index = _repository.snapshotOf(clip.profile);
    if (index == null) return false;
    if (index.isForeign(clip)) return true;
    final FileStamp? stamp = index.stampOf(clip);
    if (stamp == null) return false;
    return _metadata.lookup(relPath: clip.relPath, stamp: stamp)?.schema ==
        ClipSchema.other;
  }

  /// Whether [source] is [clip]'s own file (a foreign clip opened in the
  /// editor to be processed by hand), compared with links resolved.
  Future<bool> _isOwnFile(ClipSource source, ClipRef clip) async {
    try {
      final String file = await File(source.path).resolveSymbolicLinks();
      final String own = await File(
        _paths.absoluteFromVideos(clip.relPath),
      ).resolveSymbolicLinks();
      return file == own;
    } on FileSystemException {
      return false;
    }
  }

  /// Whether [clip] is private, as the library knows it.
  bool isPrivate(ClipRef clip) =>
      _repository.snapshotOf(clip.profile)?.isPrivate(clip) ?? false;

  /// The tags of [clip], as the library knows them.
  List<String> tagsOf(ClipRef clip) =>
      _repository.snapshotOf(clip.profile)?.tagsOf(clip) ?? const <String>[];

  /// Deletes [clip] from the gallery (kept in the trash until Undo
  /// expires: [undo] puts it back, [dismiss] makes it final; a trash left
  /// behind by a closed app is swept at the next launch) and forgets it. Throws [MediaStoreException] when the
  /// platform refused; the clip then stays.
  Future<ClipWrite> delete(ClipRef clip) async {
    final bool wasPrivate = isPrivate(clip);
    final List<String> tags = tagsOf(clip);
    final UndoToken? undo = await _publisher.delete(clip.relPath);
    if (undo == null) {
      throw MediaStoreException('Could not delete the clip ${clip.relPath}');
    }
    await _forget(clip);
    final ClipWrite write = ClipWrite(clip: clip, undo: undo);
    _deletions[clip] = write;
    if (wasPrivate) _privateDeletions.add(write);
    if (tags.isNotEmpty) _taggedDeletions[write] = tags;
    return write;
  }

  /// The deletes whose Undo is still on offer: deleted, in the trash, not
  /// yet [undo]ne nor [dismiss]ed.
  final Map<ClipRef, ClipWrite> _deletions = <ClipRef, ClipWrite>{};

  /// Those of [_deletions] whose clip was private: its Undo brings it back
  /// private at once, before its file is read again.
  final Set<ClipWrite> _privateDeletions = <ClipWrite>{};

  /// The tags of those of [_deletions] whose clip had some: its Undo
  /// brings them back at once, before its file is read again.
  final Map<ClipWrite, List<String>> _taggedDeletions =
      <ClipWrite, List<String>>{};

  /// The delete of [clip] that [undo] can still revert, for the "Video
  /// deleted" snackbar's Undo, wherever it shows (the page that deleted, or
  /// the one the viewer closed to); null once it is final.
  ClipWrite? deletionOf(ClipRef clip) => _deletions[clip];

  /// Reverts [write]: a new clip is deleted, a replaced or deleted one is
  /// put back. False when it could not be (see `MediaPublisher.undo`).
  Future<bool> undo(ClipWrite write) async {
    if (!await _publisher.undo(write.undo)) return false;
    final bool wasPrivate = _privateDeletions.contains(write);
    final List<String>? tags = _taggedDeletions[write];
    _forgetDeletion(write);
    switch (write.undo) {
      case PublishedUndo():
        await _forget(write.clip);
      case OriginalMovedUndo(:final String sourceRelPath):
        // The clip is gone; the original is back under its own name, and
        // the library learns it again (foreign, as it was) on its next
        // read.
        await _forget(write.clip);
        final ClipRef? original = ClipRef.tryParse(
          profile: write.clip.profile,
          relPath: sourceRelPath,
        );
        if (original != null) await _repository.clipAdded(original);
      case ReplacedUndo():
      case DeletedUndo():
        if (wasPrivate) {
          _repository.privacyKnown(write.clip.relPath, private: true);
        }
        if (tags != null) _repository.tagsKnown(write.clip.relPath, tags);
        await _repository.clipReplaced(write.clip);
    }
    return true;
  }

  /// The snackbar of [write] went away: its Undo is no longer offered and
  /// the trash forgets its backup.
  Future<void> dismiss(ClipWrite write) {
    _forgetDeletion(write);
    return _publisher.purge(write.undo);
  }

  void _forgetDeletion(ClipWrite write) {
    if (_deletions[write.clip] == write) _deletions.remove(write.clip);
    _privateDeletions.remove(write);
    _taggedDeletions.remove(write);
  }

  /// Takes [clip], which is gone from disk, out of the index and the
  /// metadata cache.
  Future<void> _forget(ClipRef clip) async {
    _repository.clipRemoved(clip);
    _metadata.remove(clip.relPath);
    await _metadata.flush();
  }

  Future<ClipWrite> _add(
    RenderedClip rendered,
    ProfileKey profile,
    LocalDay day, {
    required String? sourcePath,
  }) async {
    final String relPath = await _freeName(profile, day);
    final UndoToken? undo = await _publisher.publish(
      tempPath: rendered.tempPath,
      relPath: relPath,
      sourcePath: sourcePath,
    );
    if (undo == null) {
      throw MediaStoreException('Could not save the new clip $relPath');
    }
    final ClipRef clip = ClipRef(profile: profile, relPath: relPath);
    await _repository.clipAdded(clip);
    return ClipWrite(clip: clip, undo: undo);
  }

  Future<ClipWrite> _replace(
    RenderedClip rendered,
    ClipRef clip, {
    required String? sourcePath,
    required bool keepExistingSource,
  }) async {
    final UndoToken? undo = await _publisher.replace(
      tempPath: rendered.tempPath,
      relPath: clip.relPath,
      sourcePath: sourcePath,
      keepExistingSource: keepExistingSource,
    );
    if (undo == null) {
      throw MediaStoreException('Could not replace the clip ${clip.relPath}');
    }
    await _repository.clipReplaced(clip);
    return ClipWrite(clip: clip, undo: undo);
  }

  /// Deletes the save's source file when the app owns it: camera temps,
  /// picker copies and platform exports go, the user's own gallery video
  /// stays, and so does a source the editor does not own
  /// (`ClipSource.owned` false: a kept original opened with "Edit again",
  /// a foreign clip's own file).
  ///
  /// The label alone is not trusted. A file outside the app container is
  /// never the app's temp (every plugin writes its copies inside it), so it
  /// stays, whatever a caller called it: a gallery video mislabelled as a
  /// picker copy would otherwise be deleted, silently on legacy-storage
  /// Android. A file inside the videos folder always stays as well: it is a
  /// diary clip or a movie picked from the gallery, possibly the very clip
  /// just replaced. Paths are compared after resolving links, as the picker
  /// may hand out another spelling.
  Future<void> _releaseSource(ClipSource source) async {
    if (!source.owned || !source.ownership.deletableAfterSave) return;
    try {
      final String file = await File(source.path).resolveSymbolicLinks();
      final String videos = await Directory(
        _paths.videos,
      ).resolveSymbolicLinks();
      if (file.startsWith(AppPaths.withTrailingSlash(videos))) {
        _logger.warning(
          _tag,
          'Kept the source ${source.path}: it is in the diary folder',
        );
        return;
      }
      final String container = await Directory(
        _appContainer,
      ).resolveSymbolicLinks();
      if (!file.startsWith(AppPaths.withTrailingSlash(container))) {
        _logger.warning(
          _tag,
          'Kept the source ${source.path}: it is outside the app container',
        );
        return;
      }
      await File(file).delete();
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not delete the source ${source.path}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The relPath of a new clip of [day]: the next ordinal across the whole
  /// profile index, from a snapshot rescanned first when the profile's
  /// folders changed since its last scan, so a clip copied into a sub-folder
  /// meanwhile counts too. Any name already taken on disk is skipped as
  /// well, because a publish replaces a file with the same name.
  Future<String> _freeName(ProfileKey profile, LocalDay day) async {
    final ClipIndex index = await _repository.rescanIfChanged(profile);
    int ordinal = index.nextOrdinal(day);
    while (true) {
      final String path =
          '${_paths.profileVideos(profile)}'
          '${ClipNameCodec.format(day, ordinal: ordinal)}';
      if (!await File(path).exists()) return _paths.relativeToVideos(path);
      ordinal++;
    }
  }
}
