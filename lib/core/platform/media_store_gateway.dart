/// Publishes finished files into the public gallery folder and deletes them
/// again (`media_store_plus` fork on Android; plain file moves on iOS).
///
/// Pass the album on EVERY call (`AppPaths.albumFor`). Never throws: failures
/// are logged and reported as `false`.
///
/// Android may ask the user for consent (`RecoverableSecurityException`) when
/// replacing or deleting a clip the app no longer owns: `true` if allowed,
/// `false` if declined (expected, not a bug).
///
/// A call may never complete: a consent prompt raised by the last delete step
/// hangs in the fork, as does any non-consent native failure. Never hold a lock
/// across a call without a timeout; use `TimeLimitedMediaStoreGateway`.
abstract interface class MediaStoreGateway {
  /// Publishes [tempFilePath] into [album] (relative to the platform media
  /// root, e.g. `OneSecondDiary/Profiles/Work`) and removes the temp file.
  ///
  /// The published file takes the temp file's NAME: on Android the media
  /// store derives the destination from the album and that name, so the
  /// caller must give the temp file the destination's name. A file with that
  /// name already in the album is replaced. On iOS this is a move into
  /// `<Documents>/<album>/<name>`.
  Future<bool> publish({required String tempFilePath, required String album});

  /// Deletes [absolutePath], which sits in [album], from storage and from the
  /// media index. On Android the implementation falls back in three steps:
  /// plain file delete, then media store delete by name in [album], then a
  /// media-scanner lookup and delete by URI (for files the index lost track
  /// of). Deleting a file that does not exist succeeds.
  Future<bool> delete({required String absolutePath, required String album});

  /// Asks, once for the whole batch, to move or delete [absolutePaths], files
  /// inside the media root that another app may own. True when the app may go on
  /// (allowed, already owned, or no consent needed); false when the user declined.
  /// Never throws.
  Future<bool> requestWrite(List<String> absolutePaths);
}
