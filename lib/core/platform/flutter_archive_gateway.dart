import 'dart:io';

import 'package:flutter_archive/flutter_archive.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/platform/archive_gateway.dart';

/// [ArchiveGateway] over `flutter_archive`.
final class FlutterArchiveGateway implements ArchiveGateway {
  const FlutterArchiveGateway();

  @override
  Future<void> zipFilesIn({
    required String sourceDir,
    required String zipPath,
  }) async {
    try {
      await ZipFile.createFromDirectory(
        sourceDir: Directory(sourceDir),
        zipFile: File(zipPath),
        // The plugin's default is true: say false, so the zip holds the
        // session logs only.
        recurseSubDirs: false,
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StorageException('Could not zip $sourceDir', cause: error),
        stackTrace,
      );
    }
  }
}
