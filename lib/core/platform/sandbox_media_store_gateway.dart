import 'dart:io';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/media_store_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

/// [MediaStoreGateway] for iOS, where the app owns its public folder
/// outright: the clips sit in `<Documents>/OneSecondDiary`, which the user
/// browses from the Files app, and there is no media index to update.
///
/// Android uses `MediaStorePlusGateway`, which hands its publishes on
/// Android 9 and older to this class: there the app writes its DCIM album
/// by path, under its own storage root.
final class SandboxMediaStoreGateway implements MediaStoreGateway {
  SandboxMediaStoreGateway({required AppPaths paths, required this._logger})
    : _mediaRoot = Directory(paths.videos).parent.path;

  /// Shared with `MediaPublisher`, so one gallery write logs under one tag.
  static const String _tag = 'MediaGallery';

  final AppLogger _logger;

  /// The folder albums are relative to (`Documents` on iOS, `DCIM` on
  /// Android): the parent of `AppPaths.videos`.
  final String _mediaRoot;

  @override
  Future<bool> publish({
    required String tempFilePath,
    required String album,
  }) async {
    final File source = File(tempFilePath);
    final String name = source.uri.pathSegments.last;
    try {
      final Directory folder = Directory('$_mediaRoot/$album');
      await folder.create(recursive: true);
      final String destination = '${folder.path}/$name';
      try {
        await source.rename(destination);
      } on FileSystemException {
        // rename() cannot cross volumes: copy, then remove the temp.
        await source.copy(destination);
        await source.delete();
      }
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

  @override
  Future<bool> delete({
    required String absolutePath,
    required String album,
  }) async {
    final File file = File(absolutePath);
    try {
      await file.delete();
      return true;
    } on PathNotFoundException {
      return true; // Already gone: the goal is reached.
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not delete ${file.uri.pathSegments.last} from $album',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// The app owns its sandbox: nothing to ask.
  @override
  Future<bool> requestWrite(List<String> absolutePaths) async => true;
}
