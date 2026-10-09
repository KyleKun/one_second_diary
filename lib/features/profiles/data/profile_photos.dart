import 'dart:convert';
import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Profile photo files in `AppPaths.avatarsDir`: private storage, never the
/// gallery folder, which would index them.
final class ProfilePhotos {
  ProfilePhotos({
    required this._paths,
    required this._clock,
    required this._logger,
  });

  final AppPaths _paths;
  final Clock _clock;
  final AppLogger _logger;

  static const String _tag = 'PROFILES';

  /// Copies the image at [imagePath] as a new photo of [key] and returns
  /// its path relative to internal storage.
  ///
  /// Each photo gets a new file name, so a changed path refreshes every
  /// image cache. Throws a [StorageException] when the copy fails.
  Future<String> store({
    required ProfileKey key,
    required String imagePath,
  }) async {
    final String destination =
        '${_paths.avatarsDir}/${_stem(key)}-'
        '${_clock.now().millisecondsSinceEpoch}.jpg';
    try {
      await Directory(_paths.avatarsDir).create(recursive: true);
      await File(imagePath).copy(destination);
    } on FileSystemException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StorageException(
          'Cannot copy the photo of profile "${key.value}"',
          cause: error,
        ),
        stackTrace,
      );
    }
    return _paths.relativeToInternal(destination);
  }

  /// Deletes the photo at [relPath] (relative to internal storage), if any.
  /// A photo already gone is fine; a path that points outside internal
  /// storage is never followed; other failures are logged.
  Future<void> delete(String? relPath) async {
    if (relPath == null) return;
    final String path;
    try {
      path = _paths.absoluteFromInternal(relPath);
    } on ArgumentError {
      _logger.warning(_tag, 'Not deleting a photo outside internal storage');
      return;
    }
    try {
      await File(path).delete();
    } on PathNotFoundException {
      // Already gone.
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Cannot delete $path',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// A file-name stem for [key]'s photos that no other key shares, even on
  /// a case-insensitive disk and for keys holding `/`: `default`, or
  /// `p` and the key's UTF-8 bytes in lower-case hex.
  static String _stem(ProfileKey key) {
    if (key.isDefault) return 'default';
    final Iterable<String> hex = utf8
        .encode(key.value)
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'));
    return 'p${hex.join()}';
  }
}
