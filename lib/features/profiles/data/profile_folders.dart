import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/media_store_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// The profiles' folders under `<videos>Profiles/`, on disk.
final class ProfileFolders {
  ProfileFolders({
    required this._paths,
    required this._mediaStore,
    required this._logger,
  });

  final AppPaths _paths;
  final MediaStoreGateway _mediaStore;
  final AppLogger _logger;

  static const String _tag = 'PROFILES';

  String get _root => '${_paths.videos}Profiles';

  /// The names of the folders under `Profiles/`, listed as profiles or not.
  /// An unreadable folder reads as empty, with a warning.
  Future<List<String>> names() async {
    try {
      return <String>[
        await for (final FileSystemEntity entity in Directory(
          _root,
        ).list(followLinks: false))
          if (entity is Directory) entity.path.substring(_root.length + 1),
      ];
    } on PathNotFoundException {
      return <String>[];
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Cannot list $_root',
        error: error,
        stackTrace: stackTrace,
      );
      return <String>[];
    }
  }

  /// Whether [key]'s folder, or any folder below it, holds a clip-named
  /// file. Stops at the first one.
  Future<bool> holdsClip(ProfileKey key) async {
    final String folder = _paths.profileVideos(key);
    try {
      await for (final FileSystemEntity entity in Directory(
        folder,
      ).list(recursive: true, followLinks: false)) {
        if (entity is File &&
            ClipNameCodec.parse(PathNames.fileNameOf(entity.path)) != null) {
          return true;
        }
      }
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Cannot look for clips in $folder',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return false;
  }

  /// Deletes every file under [key]'s folder through the media store, each
  /// with its own album (`AppPaths.albumFor`), then the folder if no file was
  /// refused. Returns the refused files, relative to the videos folder.
  /// Throws a [StorageException] when the folder can't be listed.
  Future<List<String>> deleteFiles(ProfileKey key) async {
    final String folder = _paths.profileVideos(key);
    final List<String> kept = <String>[];
    try {
      await for (final FileSystemEntity entity in Directory(
        folder,
      ).list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final bool deleted = await _mediaStore.delete(
          absolutePath: entity.path,
          album: _paths.albumFor(entity.path),
        );
        if (!deleted) kept.add(_paths.relativeToVideos(entity.path));
      }
    } on PathNotFoundException {
      return kept;
    } on FileSystemException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StorageException('Cannot list $folder', cause: error),
        stackTrace,
      );
    }
    if (kept.isEmpty) await _deleteEmptyFolder(folder);
    return kept;
  }

  /// Deletes [folder], which holds no files any more; a failure leaves an
  /// empty folder behind and is logged.
  Future<void> _deleteEmptyFolder(String folder) async {
    try {
      await Directory(folder).delete(recursive: true);
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Cannot delete $folder',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
