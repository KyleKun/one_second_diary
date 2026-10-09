import 'dart:async';

/// Opens once the launch is done with the scratch folder: after the folder
/// migration (which stages files there) and the orphan sweep (which empties
/// it). Until then no media job may start, because the engine's `init()`
/// empties the scratch folder and the sweep would delete a job's files.
///
/// A plain class (not final), so launch tests can record when it opens.
class MediaStartGate {
  final Completer<void> _opened = Completer<void>();

  /// Completes when [open] is called.
  Future<void> get opened => _opened.future;

  /// Lets media jobs start. Calling it again does nothing.
  void open() {
    if (!_opened.isCompleted) _opened.complete();
  }
}
