import 'dart:async';
import 'dart:io';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/media_store_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';

/// The folder BESIDE the diary that holds the originals the app keeps
/// (`AppPaths.originals`): the source of every processed import and of
/// every in-app recording kept with "Keep original recordings".
///
/// - Outside `AppPaths.videos`, so the clip scanner never sees it; created
///   on first use, with a `.nomedia` file on Android so the gallery does
///   not show the originals as duplicates (iOS needs nothing). Both are
///   checked once per launch.
/// - A file keeps its path relative to the diary with its own extension
///   (`Profiles/Work/2024-01-05.mov`), so where it belonged is in the path
///   itself: the link between a clip and its source is the name, nothing
///   else. A processed import's name already taken there gets ` (2)`,
///   ` (3)`, …, never an overwrite; a kept recording takes the clip's name
///   and replaces any stale source of it.
/// - [scanNames] lists the names only (no probe) and keeps the map from
///   clip to source current through every write here; [sourcesChanged]
///   tells the library (`LibraryWiring`) each time it changes, so
///   `ClipIndex.hasSource` never touches the disk.
/// - A move is a rename where the file system allows it; a file another
///   app owns (Android 11+) goes through the media store: copied into
///   scratch, published into the Originals album, and only then deleted
///   from the diary. A declined delete leaves the original where it is and
///   takes the copy back, so the folder never holds a file twice.
/// - The app never deletes anything here except on the user's "Delete
///   originals" ([deleteAll], through the media store on Android) and
///   through `MediaPublisher`, which carries a clip's source along with
///   the clip (trashed with it, restored with it, never dropped alone).
///
/// Nothing here throws: failures are logged under `[Originals]` and
/// reported as null or false.
///
/// What the folder holds: how many originals (the `.nomedia` marker not
/// counted) and their bytes together.
typedef OriginalsContents = ({int count, int bytes});

/// Kept a plain class (not final) so the flows above it can fake it.
class OriginalsStore {
  OriginalsStore({
    required this._paths,
    required this._gateway,
    required this._logger,
    required this._isAndroid,
  });

  final AppPaths _paths;
  final MediaStoreGateway _gateway;
  final AppLogger _logger;
  final bool _isAndroid;

  static const String _tag = 'Originals';

  /// The folder, ending with `/`.
  String get folder => _paths.originals;

  /// The absolute path of the original kept at [originalRelPath] (relative
  /// to the Originals folder, a [moveIn] or [keepSource] result).
  String absoluteOf(String originalRelPath) => '$folder$originalRelPath';

  /// The source of each clip, by the clip's relPath: the path of its
  /// original relative to the folder. Filled by [scanNames], patched by
  /// every write here.
  final Map<String, String> _names = <String, String>{};

  final StreamController<Set<String>> _sources =
      StreamController<Set<String>>.broadcast();

  /// What the folder holds, walked once per launch ([contentsCached]);
  /// null until walked, or after a write here.
  Future<OriginalsContents>? _contentsCache;

  /// Whether the folder and its marker were checked this launch.
  bool _folderReady = false;

  /// The relPaths of the clips (relative to `AppPaths.videos`) whose
  /// original is in the folder, as of the last [scanNames] and the writes
  /// since.
  Set<String> get sourceRelPaths => Set<String>.unmodifiable(_names.keys);

  /// Each new value of [sourceRelPaths]: after a scan and after every
  /// write here.
  Stream<Set<String>> get sourcesChanged => _sources.stream;

  /// Where the original of the clip at [relPath] is kept, relative to the
  /// folder; null when it has none.
  String? originalRelPathOf(String relPath) => _names[relPath];

  /// The absolute path of the original of the clip at [relPath]; null when
  /// it has none.
  String? sourcePathOf(String relPath) {
    final String? original = _names[relPath];
    return original == null ? null : absoluteOf(original);
  }

  /// The relPath of the clip an original kept at [originalRelPath] belongs
  /// to: the same path with the clip extension, when the name is a clip
  /// name (`2024-01-05-2.mov` → `2024-01-05-2.mp4`); null for anything
  /// else (a ` (2)` copy, the marker, a stray file).
  static String? clipRelPathOf(String originalRelPath) {
    final String name = PathNames.fileNameOf(originalRelPath);
    if (name == PathNames.noMedia) return null;
    final String stem = _stemOf(name);
    final String clipName = '$stem.mp4';
    if (ClipNameCodec.parse(clipName) == null) return null;
    final int slash = originalRelPath.lastIndexOf('/');
    return slash < 0
        ? clipName
        : '${originalRelPath.substring(0, slash + 1)}$clipName';
  }

  /// Where a source of the clip at [relPath] goes, relative to the folder:
  /// the clip's path with the extension of [sourceName] (its own).
  static String originalRelPathFor(
    String relPath, {
    required String sourceName,
  }) {
    final int dot = sourceName.lastIndexOf('.');
    final String extension = dot < 0 ? '' : sourceName.substring(dot);
    final int clipDot = relPath.lastIndexOf('.');
    final int clipSlash = relPath.lastIndexOf('/');
    final String stem = clipDot > clipSlash
        ? relPath.substring(0, clipDot)
        : relPath;
    return '$stem$extension';
  }

  /// Lists the folder's names (never a probe) and makes them the map of
  /// sources: every file whose name is a clip name counts for that clip.
  /// Call it at launch and on resume. Returns [sourceRelPaths].
  Future<Set<String>> scanNames() async {
    final Map<String, String> found = <String, String>{};
    try {
      await for (final FileSystemEntity entity in Directory(
        folder,
      ).list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final String original = entity.path.substring(folder.length);
        final String? clip = clipRelPathOf(original);
        if (clip == null) continue;
        final String? known = found[clip];
        // Two sources of one clip (a stale one left behind): the smaller
        // name, deterministically, until the next write settles it.
        if (known == null || original.compareTo(known) < 0) {
          found[clip] = original;
        }
      }
    } on PathNotFoundException {
      // Nothing was ever kept.
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not list the Originals folder',
        error: error,
        stackTrace: stackTrace,
      );
    }
    _names
      ..clear()
      ..addAll(found);
    _announce();
    return sourceRelPaths;
  }

  /// Creates the folder, and the `.nomedia` marker on Android, when
  /// missing: checked once per launch. False (logged) when the folder
  /// cannot be created. The marker is best effort: a marker the platform
  /// refuses (a non-media name written by path) is logged and never stops
  /// an original from being kept.
  Future<bool> ensureFolder() async {
    if (_folderReady) return true;
    try {
      await Directory(folder).create(recursive: true);
    } on FileSystemException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not create the Originals folder',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
    if (_isAndroid) await _ensureMarker();
    _folderReady = true;
    return true;
  }

  /// Writes the `.nomedia` marker when missing. Once per launch (the
  /// caller remembers), so a refused marker is one WARNING with the path
  /// and the error, not one per move; the marker is checked to be there
  /// afterwards, as a platform may answer a write by path with nothing.
  Future<void> _ensureMarker() async {
    final File marker = File('$folder${PathNames.noMedia}');
    Object? error;
    StackTrace? stackTrace;
    try {
      if (!await marker.exists()) await marker.create();
      if (await marker.exists()) return;
    } on FileSystemException catch (e, s) {
      error = e;
      stackTrace = s;
    }
    _logger.warning(
      _tag,
      'Could not write the marker ${marker.path}; the gallery may show the '
      'originals as duplicates',
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// The path inside the folder, relative to it, where a file of the diary
  /// at [relPath] goes: the same path, or with ` (2)`, ` (3)`, … before the
  /// extension when that name is taken.
  Future<String> freeRelPath(String relPath) async {
    if (!await File(absoluteOf(relPath)).exists()) return relPath;
    final int dot = relPath.lastIndexOf('.');
    final int slash = relPath.lastIndexOf('/');
    final (String stem, String extension) = dot > slash
        ? (relPath.substring(0, dot), relPath.substring(dot))
        : (relPath, '');
    for (int n = 2; ; n++) {
      final String candidate = '$stem ($n)$extension';
      if (!await File(absoluteOf(candidate)).exists()) return candidate;
    }
  }

  /// Moves the diary file at [relPath] (relative to `AppPaths.videos`)
  /// into the folder under its mirrored path, or under [as] (relative to
  /// the folder) when given: a processed import's original goes under the
  /// processed clip's name with its own extension, so the link by name
  /// holds when the render took another name than the file's (a
  /// `2024-01-05.mov` processed as `2024-01-05-2.mp4` is kept as
  /// `2024-01-05-2.mov`, not as the source of the day's first clip).
  /// Returns the path it is kept at, relative to the folder; null (logged)
  /// when it could not be moved: the original is then still where it was.
  Future<String?> moveIn(String relPath, {String? as}) async {
    final String source = _paths.absoluteFromVideos(relPath);
    if (!await ensureFolder()) return null;
    final String kept = await freeRelPath(as ?? relPath);
    final String destination = absoluteOf(kept);
    bool moved = false;
    try {
      await File(destination).parent.create(recursive: true);
      await File(source).rename(destination);
      moved = true;
    } on FileSystemException {
      // Another volume, or a file another app owns: through the gallery.
    }
    if (!moved) {
      moved = await _moveThroughGallery(
        source: source,
        sourceAlbum: _paths.albumFor(source),
        destination: destination,
        destinationAlbum: _albumOf(kept),
      );
    }
    if (!moved) return null;
    _registered(kept);
    return kept;
  }

  /// Puts the original kept at [originalRelPath] back into the diary at
  /// [relPath] (the Undo of a processed import). False (logged) when it
  /// could not; the original then stays in the folder.
  Future<bool> moveBack({
    required String originalRelPath,
    required String relPath,
  }) async {
    final String source = absoluteOf(originalRelPath);
    final String destination = _paths.absoluteFromVideos(relPath);
    bool moved = false;
    try {
      await File(destination).parent.create(recursive: true);
      await File(source).rename(destination);
      moved = true;
    } on FileSystemException {
      // As in moveIn.
    }
    if (!moved) {
      moved = await _moveThroughGallery(
        source: source,
        sourceAlbum: _albumOf(originalRelPath),
        destination: destination,
        destinationAlbum: _paths.albumFor(destination),
      );
    }
    if (moved) _unregistered(originalRelPath);
    return moved;
  }

  /// Keeps the finished recording at [tempPath] (a camera temp the app
  /// owns, consumed) as the source of the clip at [relPath]: moved under
  /// the clip's name with its own extension. A
  /// stale source of that clip (another extension, left by a delete that
  /// had no Undo) goes first, so a clip never has two. Returns the path it
  /// is kept at, relative to the folder; null (logged) when it could not
  /// be kept: the temp is then still where it was.
  Future<String?> keepSource({
    required String tempPath,
    required String relPath,
  }) async {
    if (!await ensureFolder()) return null;
    final String kept = originalRelPathFor(
      relPath,
      sourceName: PathNames.fileNameOf(tempPath),
    );
    final String? stale = _names[relPath];
    if (stale != null && stale != kept && !await remove(stale)) {
      _logger.warning(_tag, 'A stale source $stale stays beside $kept');
    }
    if (!await _placeTemp(tempPath, kept)) return null;
    _registered(kept);
    return kept;
  }

  /// Copies the original kept at [originalRelPath] as the source of the
  /// clip at [toRelPath] (the converter's new profile): the folder then
  /// holds both. Returns the copy's path relative to the folder; null
  /// (logged) when it could not be copied.
  Future<String?> copySource({
    required String originalRelPath,
    required String toRelPath,
  }) async {
    final String kept = originalRelPathFor(
      toRelPath,
      sourceName: PathNames.fileNameOf(originalRelPath),
    );
    if (!await _placeCopy(absoluteOf(originalRelPath), kept)) return null;
    _registered(kept);
    return kept;
  }

  /// Puts the file at [backupPath] (a trash backup) back as the original
  /// kept at [originalRelPath] (the Undo of a replace or a delete). False
  /// (logged) when it could not.
  Future<bool> restore({
    required String backupPath,
    required String originalRelPath,
  }) async {
    if (!await _placeCopy(backupPath, originalRelPath)) return false;
    _registered(originalRelPath);
    return true;
  }

  /// Puts the file at [tempPath] (a remuxed copy in scratch, consumed) in
  /// the place of the original kept at [originalRelPath] (a privacy mark
  /// reaching the source). False (logged) when it
  /// could not; the original is then as it was. When the gallery has to be
  /// asked (old out, new in) the old original is staged in scratch first,
  /// so a refused new file puts the old one back; only a refusal of both
  /// leaves it in scratch (logged with the path), never nowhere.
  Future<bool> replaceWith({
    required String originalRelPath,
    required String tempPath,
  }) async {
    final String destination = absoluteOf(originalRelPath);
    try {
      await File(tempPath).rename(destination);
      _written();
      return true;
    } on FileSystemException {
      // Another volume: copy over it.
    }
    try {
      await File(tempPath).copy(destination);
      await _deleteQuietly(tempPath);
      _written();
      return true;
    } on FileSystemException {
      // Not writable by path: through the gallery, old out, new in.
    }
    final String staged =
        '${_paths.scratchDir}/originals/replaced/'
        '${PathNames.fileNameOf(destination)}';
    try {
      await File(staged).parent.create(recursive: true);
      await File(destination).copy(staged);
    } on FileSystemException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not stage the original $originalRelPath before replacing it',
        error: error,
        stackTrace: stackTrace,
      );
      await _deleteQuietly(tempPath);
      return false;
    }
    if (!await remove(originalRelPath)) {
      await _deleteQuietly(tempPath);
      await _deleteQuietly(staged);
      return false;
    }
    if (await _placeTemp(tempPath, originalRelPath)) {
      _registered(originalRelPath);
      await _deleteQuietly(staged);
      return true;
    }
    if (await _placeTemp(staged, originalRelPath)) {
      _registered(originalRelPath);
      _logger.warning(
        _tag,
        'The original $originalRelPath is back as it was: the remuxed copy '
        'could not take its place',
      );
      return false;
    }
    _logger.error(
      _tag,
      'The original $originalRelPath could not be put back; its copy is at '
      '$staged',
    );
    return false;
  }

  /// Deletes the original kept at [originalRelPath] (a clip's source going
  /// with its clip; the caller backed it up first). True when it is gone,
  /// already or now; false (logged) when the gateway refused.
  Future<bool> remove(String originalRelPath) async {
    final String path = absoluteOf(originalRelPath);
    try {
      await File(path).delete();
      _unregistered(originalRelPath);
      return true;
    } on PathNotFoundException {
      _unregistered(originalRelPath);
      return true;
    } on FileSystemException {
      // Not deletable by path: through the gallery.
    }
    if (await _gateway.delete(
      absolutePath: path,
      album: _albumOf(originalRelPath),
    )) {
      _unregistered(originalRelPath);
      return true;
    }
    _logger.warning(_tag, 'Could not delete the original $originalRelPath');
    return false;
  }

  /// What the folder holds ((0, 0) when there is none), walked now: every
  /// file but the marker counts, with its bytes.
  Future<OriginalsContents> contents() async {
    int count = 0;
    int bytes = 0;
    try {
      await for (final FileSystemEntity entity in Directory(
        folder,
      ).list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        if (PathNames.fileNameOf(entity.path) == PathNames.noMedia) continue;
        count++;
        bytes += await entity.length();
      }
    } on FileSystemException {
      // Missing or unreadable: nothing to count.
    }
    return (count: count, bytes: bytes);
  }

  /// [contents], walked once per launch and again after a write here.
  Future<OriginalsContents> contentsCached() => _contentsCache ??= contents();

  /// The bytes the folder holds (0 when there is none), walked now.
  Future<int> sizeBytes() async => (await contents()).bytes;

  /// [sizeBytes], walked once per launch and again after a write here.
  Future<int> sizeBytesCached() async => (await contentsCached()).bytes;

  /// Deletes every original (the user asked), through the media store on
  /// Android, then the empty folders. Returns how many files went; a file
  /// the gateway refused stays and is logged, and the `.nomedia` marker
  /// stays with it (the gallery would show it otherwise).
  Future<int> deleteAll() async {
    int deleted = 0;
    final Directory root = Directory(folder);
    try {
      final List<FileSystemEntity> entries = await root
          .list(recursive: true, followLinks: false)
          .toList();
      File? marker;
      bool allGone = true;
      for (final FileSystemEntity entity in entries) {
        if (entity is! File) continue;
        final String relative = entity.path.substring(folder.length);
        if (relative == PathNames.noMedia) {
          marker = entity;
          continue;
        }
        if (await _gateway.delete(
          absolutePath: entity.path,
          album: _albumOf(relative),
        )) {
          deleted++;
          _names.removeWhere((String _, String kept) => kept == relative);
        } else {
          allGone = false;
          _logger.warning(_tag, 'Could not delete the original $relative');
        }
      }
      if (marker != null && allGone) {
        await marker.delete();
        _folderReady = false;
      }
      await _deleteEmptyFolders(root);
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not list the Originals folder',
        error: error,
        stackTrace: stackTrace,
      );
    }
    _written();
    _announce();
    return deleted;
  }

  /// Closes [sourcesChanged].
  Future<void> dispose() => _sources.close();

  /// Moves the temp at [tempPath] (the app's, in scratch) to the original
  /// kept at [originalRelPath]: a rename, else a publish into the Originals
  /// album (the temp named like its destination first, as the media store
  /// publishes under the temp's name). False (logged) when neither
  /// worked; the temp is then still where it was (or, after a refused
  /// publish, deleted by the platform: logged).
  Future<bool> _placeTemp(String tempPath, String originalRelPath) async {
    final String destination = absoluteOf(originalRelPath);
    try {
      await File(destination).parent.create(recursive: true);
      await File(tempPath).rename(destination);
      _written();
      return true;
    } on FileSystemException {
      // Another volume (Android's app cache to DCIM): through the gallery.
    }
    final String name = PathNames.fileNameOf(destination);
    try {
      final int size = await File(tempPath).length();
      final String named = await _nameLike(tempPath, name);
      if (await _gateway.publish(
            tempFilePath: named,
            album: _albumOf(originalRelPath),
          ) &&
          await _landed(destination, size: size)) {
        _written();
        return true;
      }
      _logger.error(_tag, 'Could not keep $name in the Originals folder');
    } on FileSystemException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not keep $name in the Originals folder',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return false;
  }

  /// Copies the file at [source] (kept where it is) to the original kept
  /// at [originalRelPath]: a copy by path, else staged in scratch and
  /// published. False (logged) when neither worked.
  Future<bool> _placeCopy(String source, String originalRelPath) async {
    if (!await ensureFolder()) return false;
    final String destination = absoluteOf(originalRelPath);
    try {
      await File(destination).parent.create(recursive: true);
      await File(source).copy(destination);
      _written();
      return true;
    } on FileSystemException {
      // Not writable by path: through the gallery.
    }
    final String staged =
        '${_paths.scratchDir}/originals/'
        '${PathNames.fileNameOf(destination)}';
    try {
      await File(staged).parent.create(recursive: true);
      await File(source).copy(staged);
    } on FileSystemException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not copy ${PathNames.fileNameOf(source)} into scratch',
        error: error,
        stackTrace: stackTrace,
      );
      await _deleteQuietly(staged);
      return false;
    }
    if (await _placeTemp(staged, originalRelPath)) return true;
    await _deleteQuietly(staged);
    return false;
  }

  /// Copies [source] into scratch under [destination]'s name, publishes it
  /// into [destinationAlbum] and, once it is found there with the right
  /// size, deletes [source] from [sourceAlbum]. A declined delete takes the
  /// copy back.
  Future<bool> _moveThroughGallery({
    required String source,
    required String sourceAlbum,
    required String destination,
    required String destinationAlbum,
  }) async {
    final String name = PathNames.fileNameOf(destination);
    final String staged = '${_paths.scratchDir}/originals/$name';
    try {
      await File(staged).parent.create(recursive: true);
      final int size = await File(source).length();
      await File(source).copy(staged);
      if (!await _gateway.publish(
            tempFilePath: staged,
            album: destinationAlbum,
          ) ||
          !await _landed(destination, size: size)) {
        _logger.error(_tag, 'Could not place $name into $destinationAlbum');
        await _deleteQuietly(staged);
        return false;
      }
      if (await _gateway.delete(absolutePath: source, album: sourceAlbum)) {
        _written();
        return true;
      }
      _logger.warning(
        _tag,
        'The move of $name was refused: the original stays in $sourceAlbum',
      );
      await _gateway.delete(absolutePath: destination, album: destinationAlbum);
      return false;
    } on FileSystemException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not move $name into $destinationAlbum',
        error: error,
        stackTrace: stackTrace,
      );
      await _deleteQuietly(staged);
      return false;
    }
  }

  Future<bool> _landed(String path, {required int size}) async {
    try {
      return await File(path).length() == size;
    } on FileSystemException {
      return false;
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone, or never written.
    }
  }

  Future<void> _deleteEmptyFolders(Directory root) async {
    final List<Directory> folders = <Directory>[
      await for (final FileSystemEntity entity in root.list(
        recursive: true,
        followLinks: false,
      ))
        if (entity is Directory) entity,
    ]..sort((Directory a, Directory b) => b.path.length - a.path.length);
    for (final Directory folder in folders) {
      try {
        if (await folder.list().isEmpty) await folder.delete();
      } on FileSystemException {
        // Left as it is.
      }
    }
  }

  /// [tempPath], renamed in its folder to [name].
  static Future<String> _nameLike(String tempPath, String name) async {
    if (PathNames.fileNameOf(tempPath) == name) return tempPath;
    final File renamed = await File(
      tempPath,
    ).rename('${tempPath.substring(0, tempPath.lastIndexOf('/'))}/$name');
    return renamed.path;
  }

  /// The original kept at [originalRelPath] is in the folder now.
  void _registered(String originalRelPath) {
    final String? clip = clipRelPathOf(originalRelPath);
    if (clip != null) _names[clip] = originalRelPath;
    _written();
    _announce();
  }

  /// The original kept at [originalRelPath] left the folder.
  void _unregistered(String originalRelPath) {
    _names.removeWhere((String _, String kept) => kept == originalRelPath);
    _written();
    _announce();
  }

  /// The folder changed: its contents are walked again when asked.
  void _written() => _contentsCache = null;

  void _announce() {
    if (!_sources.isClosed) _sources.add(sourceRelPaths);
  }

  static String _stemOf(String name) {
    final int dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  /// The gallery album of the original kept at [originalRelPath]:
  /// `OneSecondDiary Originals`, or `OneSecondDiary Originals/Profiles/Work`.
  static String _albumOf(String originalRelPath) {
    final int slash = originalRelPath.lastIndexOf('/');
    return slash < 0
        ? PathNames.originalsFolder
        : '${PathNames.originalsFolder}/${originalRelPath.substring(0, slash)}';
  }
}
