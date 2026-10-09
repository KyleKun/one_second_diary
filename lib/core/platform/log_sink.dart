/// Where the app's log lines are stored: the session log file under
/// `AppPaths.logsDir`.
///
/// The only boundary of logging. `AppLogger` formats every line and applies
/// the verbose gate; a sink only stores the finished lines, so tests read the
/// real lines from a memory sink.
abstract interface class LogSink {
  /// Appends [line], one log entry (an entry with an error or a stack trace
  /// spans several text lines). Never throws and never blocks on IO: the
  /// implementation buffers, and drops what it cannot write.
  void write(String line);

  /// Completes once every line written so far is on disk, e.g. before the
  /// bug report zips the logs. Never throws.
  Future<void> flush();
}
