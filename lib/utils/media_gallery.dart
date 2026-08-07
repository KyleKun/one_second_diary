import 'dart:io' as io;

import 'package:media_store_plus/media_store_plus.dart';

import 'platform_utils.dart';
import 'utils.dart';

/// Publishes files the app produced so the rest of the system can see them, and
/// removes them again.
///
/// Android needs MediaStore for both operations: a file written straight into
/// `DCIM` is not indexed, and deleting an indexed file has to go through the
/// provider or the entry survives the file. iOS has no such index for an app
/// owned folder, so publishing is a move inside the sandbox and deleting is a
/// plain unlink.
///
/// Everything that used to talk to `media_store_plus` directly now goes through
/// [MediaGallery.instance], which keeps the Android only plugin behind a single
/// import and out of the widget layer.
abstract class MediaGallery {
  static MediaGallery? _instance;

  static MediaGallery get instance =>
      _instance ??= PlatformUtils.isAndroid ? AndroidMediaGallery() : SandboxMediaGallery();

  /// Visible for testing. Pass `null` to restore the platform default.
  static set debugInstance(MediaGallery? gallery) => _instance = gallery;

  /// Sets the album subsequent [save] calls write into, relative to the media
  /// collection root. Ignored on platforms without a media index.
  void setAlbum(String relativeFolder);

  /// Publishes [tempFilePath] and removes the temporary file.
  ///
  /// On Android, MediaStore derives the destination from the current album and
  /// the temp file name, and [destinationPath] is ignored. On iOS the file is
  /// moved to [destinationPath]. Callers must therefore give the temporary
  /// file the same name as the destination, or the two platforms would publish
  /// under different names.
  Future<bool> save({
    required String tempFilePath,
    required String destinationPath,
  });

  /// Removes [filePath] from storage, and from the media index where there is
  /// one. Never throws: failures are logged and reported through the result.
  Future<bool> delete(String filePath);
}

/// MediaStore backed implementation. Behaviour is intentionally identical to
/// what the app did inline before, including the URI fallback for entries the
/// MediaStore database has lost track of.
class AndroidMediaGallery implements MediaGallery {
  final MediaStore _mediaStore = MediaStore();

  @override
  void setAlbum(String relativeFolder) {
    MediaStore.appFolder = relativeFolder;
  }

  @override
  Future<bool> save({
    required String tempFilePath,
    required String destinationPath,
  }) async {
    final bool saved = await _mediaStore.saveFile(
      tempFilePath: tempFilePath,
      dirType: DirType.video,
      dirName: DirName.dcim,
    );
    if (saved) {
      _deleteQuietly(tempFilePath);
    } else {
      Utils.logError('[MediaGallery] - MediaStore refused to save $tempFilePath');
    }
    return saved;
  }

  @override
  Future<bool> delete(String filePath) async {
    try {
      if (io.File(filePath).existsSync()) {
        io.File(filePath).deleteSync();
      }
      return true;
    } catch (e) {
      Utils.logError('[MediaGallery] - Direct delete of $filePath failed ($e), trying MediaStore');
    }

    try {
      final bool deleted = await _mediaStore.deleteFile(
        fileName: filePath.split('/').last,
        dirType: DirType.video,
        dirName: DirName.dcim,
      );
      if (!deleted) throw Exception('MediaStore default delete failed');
      Utils.logInfo('[MediaGallery] - $filePath deleted using MediaStore');
      return true;
    } catch (e) {
      Utils.logError('[MediaGallery] - MediaStore delete failed ($e), trying the URI method');
    }

    // The MediaStore database sometimes has no record of a file that does
    // exist. Forcing a scan and deleting through the URI is the way out.
    try {
      final Uri? uri = await _mediaStore.getUriFromFilePath(path: filePath);
      if (uri == null) return false;
      final bool deleted = await _mediaStore.deleteFileUsingUri(
        uriString: uri.toString(),
        forceUseMediaStore: true,
      );
      Utils.logInfo('[MediaGallery] - $filePath deleted using the MediaStore URI method');
      return deleted;
    } catch (e) {
      Utils.logError('[MediaGallery] - Could not delete $filePath: $e');
      return false;
    }
  }

  void _deleteQuietly(String path) {
    try {
      final io.File file = io.File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // Leaving a stray temp file behind is not worth failing the operation.
    }
  }
}

/// Implementation for platforms where the app owns its folder outright, which
/// today means iOS. Videos already sit in the folder the user browses from the
/// Files app, so there is nothing to publish to a system index.
class SandboxMediaGallery implements MediaGallery {
  @override
  void setAlbum(String relativeFolder) {
    // No media index to point at.
  }

  @override
  Future<bool> save({
    required String tempFilePath,
    required String destinationPath,
  }) async {
    try {
      final io.File source = io.File(tempFilePath);
      if (!source.existsSync()) {
        Utils.logError('[MediaGallery] - $tempFilePath does not exist, nothing to save');
        return false;
      }
      await io.Directory(destinationPath.substring(0, destinationPath.lastIndexOf('/')))
          .create(recursive: true);
      try {
        await source.rename(destinationPath);
      } on io.FileSystemException {
        // rename() cannot cross volumes, fall back to a copy.
        await source.copy(destinationPath);
        await source.delete();
      }
      return true;
    } catch (e) {
      Utils.logError('[MediaGallery] - Could not save $tempFilePath to $destinationPath: $e');
      return false;
    }
  }

  @override
  Future<bool> delete(String filePath) async {
    try {
      final io.File file = io.File(filePath);
      if (file.existsSync()) await file.delete();
      return true;
    } catch (e) {
      Utils.logError('[MediaGallery] - Could not delete $filePath: $e');
      return false;
    }
  }
}
