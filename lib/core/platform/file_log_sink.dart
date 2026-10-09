import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:one_second_diary/core/platform/log_sink.dart';

/// The session log file: a [LogSink] over a buffered [IOSink] that appends
/// to one file under `AppPaths.logsDir`.
///
/// One [IOSink] stays open for the session and writes in the background.
/// Two [IOSink] rules shape this class:
/// - it throws a `StateError` for any write made while a flush is in
///   flight, so lines written then are held in memory and handed to the sink
///   as soon as that flush completes; flushes run one at a time;
/// - it reports a failed open or write only through its futures. Once that
///   happens the file is gone for this session: later lines are dropped, as
///   the [LogSink] contract allows, because there is nowhere left to log.
final class FileLogSink implements LogSink {
  FileLogSink._(this._sink) {
    // Nobody else listens to `done`: without this handler a failed open
    // would surface as an uncaught asynchronous error.
    unawaited(_sink.done.then<void>((_) {}, onError: _stop));
  }

  /// Appends to the file at [path]. Never throws: when the file cannot be
  /// opened, the lines are dropped.
  factory FileLogSink.open(String path) =>
      FileLogSink._(File(path).openWrite(mode: FileMode.writeOnlyAppend));

  final IOSink _sink;

  /// Lines written while the sink is flushing.
  final StringBuffer _held = StringBuffer();
  bool _isFlushing = false;
  bool _isClosed = false;
  Future<void> _flushes = Future<void>.value();

  @override
  void write(String line) {
    if (_isClosed) return;
    if (_isFlushing) {
      _held.writeln(line);
    } else {
      _sink.writeln(line);
    }
  }

  @override
  Future<void> flush() => _flushes = _flushes.then((_) => _flushOnce());

  Future<void> _flushOnce() async {
    if (_isClosed) return;
    _isFlushing = true;
    try {
      await _sink.flush();
    } on Object catch (error) {
      _stop(error);
    } finally {
      _isFlushing = false;
      if (_held.isNotEmpty && !_isClosed) _sink.write(_held);
      _held.clear();
    }
  }

  /// Flushes and closes the file. Later lines are dropped.
  Future<void> close() async {
    await _flushes;
    if (_isClosed) return;
    _isClosed = true;
    try {
      await _sink.close();
    } on Object catch (error) {
      _stop(error);
    }
  }

  void _stop(Object error) {
    if (_isClosed) return;
    _isClosed = true;
    debugPrint('The log file failed, later log lines are dropped: $error');
  }
}
