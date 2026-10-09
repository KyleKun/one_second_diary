import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';

/// Whether a save adds a clip to its day or replaces one.
sealed class ClipSaveMode extends Equatable {
  const ClipSaveMode();
}

/// A new clip of the day, after the ones it already has.
final class AddClip extends ClipSaveMode {
  const AddClip();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A new version of [clip], under the same name.
final class ReplaceClip extends ClipSaveMode {
  const ReplaceClip(this.clip);

  final ClipRef clip;

  @override
  List<Object?> get props => <Object?>[clip];
}
