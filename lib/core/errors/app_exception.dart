/// The app's own failures, thrown by gateways and services.
///
/// Cubits catch these and map them to failure enums; raw exception text never
/// reaches the UI. The set is small on purpose: add a subtype only when a
/// caller has to react to it differently.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  /// What went wrong, for the log. Not shown to the user.
  final String message;

  /// The underlying error, if any (a `FileSystemException`, a
  /// `PlatformException`, …).
  final Object? cause;

  @override
  String toString() {
    // Spelled out rather than `runtimeType`, which obfuscation would mangle.
    final String type = switch (this) {
      StorageException() => 'StorageException',
      StorageShortException() => 'StorageShortException',
      VideoProcessingException() => 'VideoProcessingException',
      NotEnoughClipsException() => 'NotEnoughClipsException',
      PermissionDeniedException() => 'PermissionDeniedException',
      MediaStoreException() => 'MediaStoreException',
      CancelledException() => 'CancelledException',
      CameraFailureException() => 'CameraFailureException',
    };
    return cause == null
        ? '$type: $message'
        : '$type: $message (cause: $cause)';
  }
}

/// Reading, writing, moving or deleting a file or a preference failed.
final class StorageException extends AppException {
  const StorageException(super.message, {super.cause});
}

/// A heavy job was refused before any work: the phone lacks
/// [shortfallBytes] for it beyond the floor every job leaves free
/// (`StorageBudget.check`). The message to the user says how
/// much to free (`Strings.storageShort`).
final class StorageShortException extends AppException {
  StorageShortException({required this.shortfallBytes})
    : super('Not enough free space: $shortfallBytes bytes short');

  final int shortfallBytes;
}

/// An ffmpeg or ffprobe job failed.
final class VideoProcessingException extends AppException {
  const VideoProcessingException(
    super.message, {
    required this.returnCode,
    required this.logTail,
    super.cause,
  });

  /// The session's return code; null when no session ran or it returned none.
  final int? returnCode;

  /// The last lines of the session log, for the local log file and the
  /// "Report error" email.
  final String logTail;
}

/// A movie was left with fewer than two clips once the clips that cannot be
/// read were left out. Not a failure of ffmpeg: the movie job says there are
/// too few clips instead of offering a report.
final class NotEnoughClipsException extends AppException {
  const NotEnoughClipsException(super.message, {required this.skipped});

  /// How many clips were left out.
  final int skipped;
}

/// The user (or the OS) refused a permission the operation needs.
final class PermissionDeniedException extends AppException {
  const PermissionDeniedException(
    super.message, {
    required this.permanentlyDenied,
    super.cause,
  });

  /// True when asking again is pointless and only the system settings page
  /// can grant it.
  final bool permanentlyDenied;
}

/// Publishing to or deleting from the platform media index (Android
/// MediaStore) failed.
final class MediaStoreException extends AppException {
  const MediaStoreException(super.message, {super.cause});
}

/// The operation was cancelled on purpose (a `CancelToken`, the user leaving
/// the screen). Not an error to report.
final class CancelledException extends AppException {
  const CancelledException(super.message, {super.cause});
}

/// The camera could not be opened, or failed or was released while in use.
final class CameraFailureException extends AppException {
  const CameraFailureException(super.message, {super.cause});
}
