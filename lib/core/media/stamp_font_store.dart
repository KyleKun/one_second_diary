import 'dart:io';
import 'dart:typed_data';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/policy/stamp_font.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

/// The stamp fonts copied out of the app bundle for ffmpeg, which cannot
/// read Flutter assets.
///
/// Each copy has a VERSIONED name (`StampFont.fileName`) in
/// `AppPaths.fontsDir`, so a changed asset reaches an existing install.
final class StampFontStore {
  StampFontStore({required this._paths, required this._loadAsset});

  final AppPaths _paths;
  final Future<ByteData> Function(String assetKey) _loadAsset;

  /// The path of [font]'s copy, made from the asset when this version is not
  /// there yet.
  ///
  /// The copy is written under a temporary name and renamed into place, so
  /// a copy cut short (app killed, disk full) never sits under the final
  /// name, where it would be reused forever. Throws a [StorageException]
  /// when the copy fails.
  Future<String> install(StampFont font) async {
    final String path = font.pathIn(_paths);
    if (await File(path).exists()) return path;
    final File partial = File('$path.part');
    try {
      final ByteData data = await _loadAsset(font.assetKey);
      await Directory(_paths.fontsDir).create(recursive: true);
      await partial.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      await partial.rename(path);
      return path;
    } on Object catch (error, stackTrace) {
      await _deleteQuietly(partial);
      Error.throwWithStackTrace(
        StorageException('Could not copy ${font.assetKey}', cause: error),
        stackTrace,
      );
    }
  }

  /// The font copies of older installs: v1.7's unversioned ones (6 MB of
  /// duplicate font) and the trimmed Noto Sans no stamp uses any more.
  static const List<String> legacyFileNames = <String>[
    'magic.ttf',
    'datestamp_fallback.ttf',
    'NotoSans-DateStamp.v1.ttf',
  ];

  /// Deletes the [legacyFileNames].
  Future<void> removeLegacyCopies() async {
    for (final String name in legacyFileNames) {
      await _deleteQuietly(File('${_paths.fontsDir}/$name'));
    }
  }

  /// Deletes [file] if it is there; other failures are thrown.
  static Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } on PathNotFoundException {
      // Not there: nothing to delete.
    }
  }
}
