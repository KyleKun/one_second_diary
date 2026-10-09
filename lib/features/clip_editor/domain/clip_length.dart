import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clip_editor/domain/trim_selection.dart';

/// How long the saved clip is: a trimmed video or a photo held still.
sealed class ClipLength extends Equatable {
  const ClipLength();
}

/// A video source, trimmed to [trim].
final class TrimmedVideo extends ClipLength {
  const TrimmedVideo(this.trim);

  final TrimSelection trim;

  @override
  List<Object?> get props => <Object?>[trim];
}

/// A photo source, held for [durationMs] (one of
/// `SettingsRepository.photoDurationsMs`).
final class HeldPhoto extends ClipLength {
  const HeldPhoto(this.durationMs);

  final int durationMs;

  @override
  List<Object?> get props => <Object?>[durationMs];
}
