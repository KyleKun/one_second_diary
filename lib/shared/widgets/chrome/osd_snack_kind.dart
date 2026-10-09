/// What a snackbar reports.
enum OsdSnackKind {
  /// A green check: saved, created, copied.
  success,

  /// A red error: something failed.
  error,

  /// A red bin: something was deleted (usually with Undo).
  delete,

  /// A neutral info badge.
  info,
}
