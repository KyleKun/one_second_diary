import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_backfill.dart';

/// A [ClipMetadataBackfill] the test drives: it counts its pauses
/// ([paused] while any [pause] waits for its [resume]) and runs when the
/// test says ([startReading] tells [progress] and holds [whenIdle] until
/// [finishReading]). Idle at first.
class PausableBackfill extends Fake implements ClipMetadataBackfill {
  int _pauses = 0;
  final StreamController<void> _progress = StreamController<void>.broadcast();
  Completer<void>? _run;

  /// Whether the backfill is held (a movie is being made).
  bool get paused => _pauses > 0;

  /// Whether clips are being read.
  bool get reading => _run != null;

  @override
  void pause() => _pauses++;

  @override
  void resume() {
    if (_pauses > 0) _pauses--;
  }

  @override
  Stream<void> get progress => _progress.stream;

  @override
  Future<void> get whenIdle => _run?.future ?? Future<void>.value();

  @override
  bool get isRunning => _run != null;

  /// Clips are being read: [progress] fires and [whenIdle] waits.
  void startReading() {
    _run ??= Completer<void>();
    _progress.add(null);
  }

  /// Every clip is read: [whenIdle] completes.
  void finishReading() {
    _run?.complete();
    _run = null;
  }

  @override
  Future<void> dispose() async {
    finishReading();
    await _progress.close();
  }
}
