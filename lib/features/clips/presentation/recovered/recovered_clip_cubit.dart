import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/features/clips/domain/import_result.dart';
import 'package:one_second_diary/features/clips/presentation/recovered/recovered_clip_state.dart';

/// Hands a recording Android kept while it had killed the app from the app
/// root to Today, app-scoped. Today [take]s what `LostPickListener` [offer]s.
class RecoveredClipCubit extends Cubit<RecoveredClipState> {
  RecoveredClipCubit() : super(const RecoveredClipState.none());

  /// [clip] waits for Today.
  void offer(RecoveredClip clip) => emit(RecoveredClipState.waiting(clip));

  /// The clip that waits, if any; it is handed out once.
  RecoveredClip? take() {
    final RecoveredClip? clip = state.clip;
    if (clip != null) emit(const RecoveredClipState.none());
    return clip;
  }
}
