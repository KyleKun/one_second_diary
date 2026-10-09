import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/import_result.dart';

/// Whether a recording Android kept waits to be opened.
enum RecoveredClipStatus {
  /// Nothing waits.
  none,

  /// [RecoveredClipState.clip] waits for Today to open it.
  waiting,
}

/// A recording Android kept while it had killed the app, until Today
/// opens it (`RecoveredClipCubit`).
final class RecoveredClipState extends Equatable {
  const RecoveredClipState.none() : clip = null;

  const RecoveredClipState.waiting(RecoveredClip this.clip);

  /// The recording and its day; null when nothing waits.
  final RecoveredClip? clip;

  RecoveredClipStatus get status =>
      clip == null ? RecoveredClipStatus.none : RecoveredClipStatus.waiting;

  @override
  List<Object?> get props => <Object?>[clip];
}
