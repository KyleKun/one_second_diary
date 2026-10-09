import 'dart:async';
import 'dart:io';

import 'package:media_store_plus/media_store_plus.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/media_store_gateway.dart';

/// [MediaStoreGateway] for Android, over the owner's `media_store_plus`
/// fork; iOS uses `SandboxMediaStoreGateway`.
///
/// Every call passes its album and also sets the plugin's global
/// `MediaStore.appFolder` right before the call (the plugin refuses to work
/// while it is empty).
///
/// **One call at a time.** The fork keeps a single pending answer per plugin,
/// so two calls in flight could answer the wrong caller or twice. [publish]
/// and [delete] run in call order: a call waiting longer than [turnTimeLimit]
/// gives up with a logged `false`, as does every later call until the running
/// one answers. The running call is never cut short; a caller that must finish
/// wraps the gateway in `TimeLimitedMediaStoreGateway`.
///
/// **Consent** (clips the app no longer owns): the fork shows Android's prompt
/// and answers once the user has. Step 3 of [delete] is the exception: allowing
/// there makes the fork retry with `DocumentsContract.deleteDocument` on a media
/// store URI, which throws and is never answered, so the call never completes.
/// After a declined step 2 this gateway stops instead of asking in step 3.
///
/// Any other native failure is logged by the fork and never answered.
final class MediaStorePlusGateway implements MediaStoreGateway {
  /// [mediaStore] makes the plugin. It runs on the first gallery call, not
  /// here: `MediaStore()` asks the platform for its SDK level, and the app root
  /// builds this gateway in the first frame, which calls no platform.
  ///
  /// [byPath] publishes on Android 9 and older, where the fork copies to a
  /// hard-coded `/storage/emulated/0/DCIM/<album>` that secondary users, work
  /// profiles and Secure Folder can't write to; it moves the file into the album
  /// under the app's own storage root (`SandboxMediaStoreGateway`).
  MediaStorePlusGateway({
    required MediaStore Function() mediaStore,
    required this._byPath,
    required this._logger,
  }) : _makeMediaStore = mediaStore;

  /// The first SDK level whose media store takes an insert by relative
  /// path (Android 10).
  static const int _scopedStorageSdk = 29;

  /// How long a call waits for the call before it to answer. Long enough
  /// for a person to read and answer a consent prompt.
  static const Duration turnTimeLimit = Duration(minutes: 2);

  /// Shared with `MediaPublisher`, so one gallery write logs under one tag.
  static const String _tag = 'MediaGallery';

  final MediaStore Function() _makeMediaStore;
  late final MediaStore _mediaStore = _makeMediaStore();
  final MediaStoreGateway _byPath;
  final AppLogger _logger;

  /// Completes when the last call handed to [_oneAtATime] has finished.
  Future<void> _lastCall = Future<void>.value();

  /// What the call running on the plugin is doing, for the logs.
  String? _running;

  /// Whether a call gave up waiting for the running one. Until that one
  /// answers, later calls give up at once instead of each waiting
  /// [turnTimeLimit].
  bool _stuck = false;

  @override
  Future<bool> publish({required String tempFilePath, required String album}) =>
      _oneAtATime(
        'publishing ${_nameOf(tempFilePath)} into $album',
        () => _publish(tempFilePath, album),
      );

  /// Three steps, each tried when the one before fails: a plain
  /// unlink, a media store delete by name in [album], then a scan of the
  /// path and a delete by URI.
  @override
  Future<bool> delete({required String absolutePath, required String album}) =>
      _oneAtATime(
        'deleting ${_nameOf(absolutePath)} from $album',
        () => _delete(absolutePath, album),
      );

  /// The fork has no `MediaStore.createWriteRequest` yet, so this answers from
  /// what the platform knows without a prompt: below Android 11 the app's own
  /// permission covers every file; from 11 on a file the app does not own raises
  /// the per-file consent prompt when its move deletes it (`delete`, step 2),
  /// which the caller treats as a declined move for that file.
  @override
  Future<bool> requestWrite(List<String> absolutePaths) async {
    try {
      if (await _sdkLevelKnown() < _batchConsentSdk) return true;
      int foreign = 0;
      for (final String path in absolutePaths) {
        final Uri? uri = await _mediaStore.getUriFromFilePath(path: path);
        if (uri == null ||
            !await _mediaStore.isFileWritable(uriString: uri.toString())) {
          foreign++;
        }
      }
      if (foreign > 0) {
        _logger.info(
          _tag,
          '$foreign of ${absolutePaths.length} file(s) belong to another '
          'app; each move will ask for consent',
        );
      }
      return true;
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not check who owns the files to move; going on',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    }
  }

  /// The first SDK level whose media store asks consent to change files
  /// another app owns (Android 11, `createWriteRequest`).
  static const int _batchConsentSdk = 30;

  /// Runs [call] once every earlier call has finished, or gives up with
  /// false when that takes longer than [turnTimeLimit].
  Future<bool> _oneAtATime(
    String description,
    Future<bool> Function() call,
  ) async {
    final Future<void> before = _lastCall;
    final Completer<void> done = Completer<void>();
    _lastCall = done.future;
    if (!await _turnCame(before, description)) {
      // The calls after this one still wait for the one that is running.
      unawaited(before.whenComplete(done.complete));
      return false;
    }
    _running = description;
    try {
      return await call();
    } finally {
      _running = null;
      _stuck = false;
      done.complete();
    }
  }

  /// Waits for [before]; false (logged) when the call running on the plugin
  /// has not answered in time.
  Future<bool> _turnCame(Future<void> before, String description) async {
    if (_stuck) {
      _logger.error(
        _tag,
        'Gave up $description: $_running still has not answered',
      );
      return false;
    }
    try {
      await before.timeout(turnTimeLimit);
      return true;
    } on TimeoutException {
      _stuck = true;
      _logger.error(
        _tag,
        'Gave up $description: $_running has not answered for '
        '${turnTimeLimit.inMinutes} minutes (a consent prompt still open, or '
        'a native failure the plugin never answers)',
      );
      return false;
    }
  }

  Future<bool> _publish(String tempFilePath, String album) async {
    final String name = _nameOf(tempFilePath);
    try {
      if (await _sdkLevelKnown() < _scopedStorageSdk) {
        return await _byPath.publish(tempFilePath: tempFilePath, album: album);
      }
      MediaStore.appFolder = album;
      final bool saved = await _mediaStore.saveFile(
        tempFilePath: tempFilePath,
        dirType: DirType.video,
        dirName: DirName.dcim,
        relativePath: album,
      );
      if (!saved) {
        _logger.error(_tag, 'MediaStore refused to save $name into $album');
        return false;
      }
      await _removeTemp(tempFilePath);
      return true;
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not publish $name into $album',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> _delete(String absolutePath, String album) async {
    final String name = _nameOf(absolutePath);
    if (await _unlink(absolutePath, name)) return true;
    return switch (await _deleteByName(name, album)) {
      _ByName.deleted => true,
      _ByName.declined => false,
      _ByName.notListed => await _deleteByScan(absolutePath, name, album),
    };
  }

  /// Works for files this install created; a missing file counts as
  /// deleted.
  Future<bool> _unlink(String path, String name) async {
    try {
      await File(path).delete();
      return true;
    } on PathNotFoundException {
      return true;
    } on FileSystemException catch (error) {
      _logger.warning(
        _tag,
        'Could not unlink $name ($error), trying the media store',
      );
      return false;
    }
  }

  /// The fork answers false both when the index has no [name] in [album] and
  /// when the user declined its prompt. Only the first needs step 3 (a second
  /// prompt would hang the fork), so a false is followed by a lookup of the name.
  Future<_ByName> _deleteByName(String name, String album) async {
    try {
      await _sdkLevelKnown();
      MediaStore.appFolder = album;
      if (await _mediaStore.deleteFile(
        fileName: name,
        dirType: DirType.video,
        dirName: DirName.dcim,
        relativePath: album,
      )) {
        return _ByName.deleted;
      }
    } on Object catch (error) {
      _logger.warning(
        _tag,
        'MediaStore delete of $name failed ($error), scanning it',
      );
      return _ByName.notListed;
    }
    if (await _isListed(name, album)) {
      _logger.warning(
        _tag,
        'Kept $name in $album: the user declined to delete it',
      );
      return _ByName.declined;
    }
    _logger.warning(_tag, 'MediaStore has no $name in $album, scanning it');
    return _ByName.notListed;
  }

  /// Whether the index lists [name] in [album]. A failed lookup reads as
  /// not listed, so the delete goes on to step 3.
  Future<bool> _isListed(String name, String album) async {
    try {
      return await _mediaStore.getFileUri(
            fileName: name,
            dirType: DirType.video,
            dirName: DirName.dcim,
            relativePath: album,
          ) !=
          null;
    } on Object catch (error) {
      _logger.warning(_tag, 'Could not look $name up in $album ($error)');
      return false;
    }
  }

  /// The index sometimes has no record of a file that does exist: a scan of
  /// the path, then a delete by URI, is the way out.
  Future<bool> _deleteByScan(String path, String name, String album) async {
    try {
      final Uri? uri = await _mediaStore.getUriFromFilePath(path: path);
      if (uri == null) {
        _logger.error(_tag, 'Could not delete $name from $album: not indexed');
        return false;
      }
      final bool deleted = await _mediaStore.deleteFileUsingUri(
        uriString: uri.toString(),
        forceUseMediaStore: true,
      );
      if (!deleted) {
        _logger.warning(_tag, 'MediaStore refused to delete $name from $album');
      }
      return deleted;
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not delete $name from $album',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Android 10+ deletes the temp natively after a save. A stray temp is
  /// not worth failing a publish that happened.
  Future<void> _removeTemp(String path) async {
    try {
      await File(path).delete();
    } on PathNotFoundException {
      // Already removed by the plugin.
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Published ${_nameOf(path)} but could not remove its temp file',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The SDK level. `MediaStore()` asks for it in its constructor without
  /// waiting, and until that lands every call takes the Android 9 branch. This
  /// query goes out on the same channel after it, so once it answers the
  /// plugin's own field is set.
  Future<int> _sdkLevelKnown() => _mediaStore.getPlatformSDKInt();

  static String _nameOf(String path) =>
      path.substring(path.lastIndexOf('/') + 1);
}

/// How step 2 (the media store delete by name) ended.
enum _ByName {
  deleted,

  /// Still listed: the user declined the consent prompt.
  declined,

  /// Not listed under that name, or the plugin failed: step 3 comes next.
  notListed,
}
