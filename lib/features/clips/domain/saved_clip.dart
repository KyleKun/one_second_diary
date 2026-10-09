import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_write.dart';
import 'package:one_second_diary/features/clips/domain/undo_token.dart';

/// What the clip editor pops with after a save: the clip on disk and the Undo
/// of that save. Undo hands [write] to `ClipStore.undo`; the snackbar going
/// away hands it to `ClipStore.dismiss`.
final class SavedClip extends Equatable {
  const SavedClip({required this.ref, required this.undoToken});

  /// The result of `ClipStore.save`.
  factory SavedClip.of(ClipWrite write) =>
      SavedClip(ref: write.clip, undoToken: write.undo);

  /// The clip the save wrote (its day, ordinal and profile).
  final ClipRef ref;

  final UndoToken undoToken;

  /// The store's write, for `ClipStore.undo` and `ClipStore.dismiss`.
  ClipWrite get write => ClipWrite(clip: ref, undo: undoToken);

  /// Whether the save replaced a clip (Re-record, Replace from gallery)
  /// rather than adding one to the day.
  bool get replaced =>
      undoToken is ReplacedUndo || undoToken is OriginalMovedUndo;

  @override
  List<Object?> get props => <Object?>[ref, undoToken];
}
