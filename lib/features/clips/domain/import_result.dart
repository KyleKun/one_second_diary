import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';

/// How an import (Add video, Add photo, the system camera) ended.
sealed class ImportResult extends Equatable {
  const ImportResult();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A file to make the clip from, with who owns it: open the clip editor
/// with it (`EditClipArgs(source: …)`).
final class ImportPicked extends ImportResult {
  const ImportPicked(this.source);

  final ClipSource source;

  @override
  List<Object?> get props => <Object?>[source];
}

/// The user left the picker without picking.
final class ImportCancelled extends ImportResult {
  const ImportCancelled();
}

/// The phone refused the gallery or camera permission: explain, and offer
/// the system settings.
final class ImportDenied extends ImportResult {
  const ImportDenied();
}

/// The picked item could not be loaded (an iCloud item that did not
/// download, limited access): say so instead of doing nothing.
final class ImportUnavailable extends ImportResult {
  const ImportUnavailable();
}

/// The pick is the very clip the save would replace: refused, so the only
/// copy is never both the input and the output.
final class ImportRejected extends ImportResult {
  const ImportRejected();
}

/// A recording or photo Android kept after it killed the app while the
/// system camera or picker was open, and the day it belongs to: the day its
/// file was written (the day recording stopped), else today. The app opens
/// the clip editor with it once the launch is done
/// (`EditClipArgs(recovered: true)`).
final class RecoveredClip extends Equatable {
  const RecoveredClip({required this.source, required this.day});

  final ClipSource source;
  final LocalDay day;

  @override
  List<Object?> get props => <Object?>[source, day];
}
