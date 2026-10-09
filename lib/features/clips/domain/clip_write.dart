import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/undo_token.dart';

/// A clip the app saved, replaced or deleted, with the Undo of that write.
final class ClipWrite extends Equatable {
  const ClipWrite({required this.clip, required this.undo});

  final ClipRef clip;
  final UndoToken undo;

  @override
  List<Object?> get props => <Object?>[clip, undo];
}
