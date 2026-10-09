import 'package:equatable/equatable.dart';

/// What the "Undo" of one gallery write needs: which file, and where its
/// backup waits in `AppPaths.trashDir`. Returned by `MediaPublisher` and
/// handed back to it to undo or purge.
sealed class UndoToken extends Equatable {
  const UndoToken({required this.relPath});

  /// The file written, relative to `AppPaths.videos`.
  final String relPath;

  /// Whether Undo can work: false for a delete made without a backup (the
  /// trash had no room), so the snackbar hides its Undo action.
  bool get canUndo => true;

  /// Where the write kept the clip's original, relative to the Originals
  /// folder; null when the write kept none (a recording's temp is then still
  /// the caller's to release).
  String? get keptSourceRelPath => null;
}

/// A new file was published; Undo deletes it again, with the source it
/// kept.
final class PublishedUndo extends UndoToken {
  const PublishedUndo({required super.relPath, this.keptSourceRelPath});

  @override
  final String? keptSourceRelPath;

  @override
  List<Object?> get props => <Object?>[relPath, keptSourceRelPath];
}

/// An existing clip was replaced; Undo puts the old one back, with the old
/// source the trash entry holds, and removes the source kept for the new
/// one.
final class ReplacedUndo extends UndoToken {
  const ReplacedUndo({
    required super.relPath,
    required this.trashId,
    this.keptSourceRelPath,
  });

  /// The trash entry holding the old clip (and its source, when it had
  /// one).
  final String trashId;

  @override
  final String? keptSourceRelPath;

  @override
  List<Object?> get props => <Object?>[relPath, trashId, keptSourceRelPath];
}

/// A foreign video was processed into a clip: its original went beside the
/// diary (`OriginalsStore`) and the render took its day name. Undo deletes the
/// clip and brings the original back where it was.
final class OriginalMovedUndo extends UndoToken {
  const OriginalMovedUndo({
    required super.relPath,
    required this.originalRelPath,
    required this.sourceRelPath,
  });

  /// Where the original is kept, relative to the Originals folder.
  final String originalRelPath;

  /// Where the original was, relative to `AppPaths.videos` (the clip's own
  /// name, or a `.mov` beside it).
  final String sourceRelPath;

  /// The moved original is the processed clip's source now.
  @override
  String? get keptSourceRelPath => originalRelPath;

  @override
  List<Object?> get props => <Object?>[relPath, originalRelPath, sourceRelPath];
}

/// A clip was deleted; Undo puts it back, with the source the trash entry
/// holds.
final class DeletedUndo extends UndoToken {
  const DeletedUndo({required super.relPath, required this.trashId});

  /// The trash entry holding the deleted clip; null when no backup could be
  /// made.
  final String? trashId;

  @override
  bool get canUndo => trashId != null;

  @override
  List<Object?> get props => <Object?>[relPath, trashId];
}
