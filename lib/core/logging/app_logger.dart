import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/log_sink.dart';

/// Severity of a log line, lowest first.
///
/// [verbose] lines are written only while the `verboseLogging` preference is
/// on (coordinates and other detail kept out of normal logs).
enum LogLevel { verbose, info, warning, error }

/// The app's local log. Nothing is ever sent anywhere: the file is attached
/// only when the user taps "Report error".
///
/// Formats every line as `[LEVEL] <local time>: <message>`, with the
/// caller's bracketed prefix as the start of the message:
/// `[INFO] 2024-01-05 20:30:15.250: [PREFERENCES] verboseLogging: true`.
/// [tag] is that prefix without the brackets (`PREFERENCES`, `CALENDAR`,
/// `NOTIFICATIONS`, `ffmpeg`, …).
///
/// Calls never throw and never block on IO (the [LogSink] buffers), so they
/// are safe anywhere, including in `catch` blocks and error handlers.
final class AppLogger {
  AppLogger({
    required this._sink,
    required this._clock,
    required this._isVerboseEnabled,
  });

  final LogSink _sink;
  final Clock _clock;

  /// Reads the `verboseLogging` preference at each verbose call.
  final bool Function() _isVerboseEnabled;

  void verbose(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => _write(LogLevel.verbose, tag, message, error, stackTrace);

  void info(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => _write(LogLevel.info, tag, message, error, stackTrace);

  void warning(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => _write(LogLevel.warning, tag, message, error, stackTrace);

  void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => _write(LogLevel.error, tag, message, error, stackTrace);

  /// Completes once every line logged so far is on disk (call it before
  /// zipping the logs). Never throws.
  Future<void> flush() => _sink.flush();

  void _write(
    LogLevel level,
    String tag,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (level == LogLevel.verbose && !_isVerboseEnabled()) return;
    final StringBuffer line = StringBuffer(
      '[${level.name.toUpperCase()}] ${_clock.now()}: [$tag] $message',
    );
    if (error != null) line.write('\nError: $error');
    if (stackTrace != null) line.write('\nStacktrace: $stackTrace');
    _sink.write(line.toString());
  }
}
