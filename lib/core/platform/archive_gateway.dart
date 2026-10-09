/// Zips files (`flutter_archive`), for the bug report.
abstract interface class ArchiveGateway {
  /// Writes a zip at [zipPath] holding the files directly inside
  /// [sourceDir], at the zip's root: not its sub-folders, and not the folder
  /// itself as a parent entry (`includeBaseDirectory: false,
  /// recurseSubDirs: false`). Throws a `StorageException` (the plugin error
  /// as its cause) when the zip cannot be written.
  Future<void> zipFilesIn({required String sourceDir, required String zipPath});
}
