/// Where a bundled document page (Changelog, Special thanks) is.
enum DocumentStatus {
  /// The file is being read.
  loading,

  /// The content is there.
  ready,

  /// The file could not be read (logged).
  failed,
}
