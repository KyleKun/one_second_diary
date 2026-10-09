import 'package:equatable/equatable.dart';

/// Size and last-modified time of a clip file, as the scan saw it.
///
/// Every per-clip cache (metadata, thumbnails) is validated against it: a
/// clip rewritten in place (a subtitle edit, a Files-app replace) keeps its
/// path but gets a new stamp, so stale cached facts are never served.
final class FileStamp extends Equatable {
  const FileStamp({required this.sizeBytes, required this.modifiedMs});

  final int sizeBytes;

  /// Milliseconds since the epoch (UTC).
  final int modifiedMs;

  @override
  List<Object?> get props => <Object?>[sizeBytes, modifiedMs];
}
