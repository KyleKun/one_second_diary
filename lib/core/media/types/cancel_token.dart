import 'dart:async';

import 'package:one_second_diary/core/errors/app_exception.dart';

/// Lets a caller cancel a running media job (a save, a remux, a movie).
///
/// The caller keeps the token and calls [cancel]. The job checks
/// [throwIfCancelled] between steps and listens to [whenCancelled] to cancel
/// the running ffmpeg session right away.
final class CancelToken {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  /// Completes (once) when [cancel] is first called; never completes
  /// otherwise.
  Future<void> get whenCancelled => _cancelled.future;

  /// Requests cancellation. Safe to call more than once.
  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }

  /// Throws a [CancelledException] if [cancel] was called.
  void throwIfCancelled() {
    if (isCancelled) throw const CancelledException('Cancelled by the caller');
  }
}
