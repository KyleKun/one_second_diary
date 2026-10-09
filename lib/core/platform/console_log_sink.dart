import 'package:one_second_diary/core/platform/log_sink.dart';

/// The fallback [LogSink] for a launch whose log file could not be created
/// (`LogSession.open` threw): lines go to the console (`debugPrint` in the
/// app, logcat or the Xcode console on a device) instead of nowhere.
///
/// A bug report of such a session has no log of it; the console still shows
/// what happened while the device is connected.
final class ConsoleLogSink implements LogSink {
  /// Bootstrap passes `debugPrint`.
  ConsoleLogSink({required this._print});

  final void Function(String line) _print;

  @override
  void write(String line) => _print(line);

  /// Nothing is buffered.
  @override
  Future<void> flush() async {}
}

/// A [LogSink] that also prints every line: debug builds show the log in
/// the terminal as well as in the session file.
final class EchoingLogSink implements LogSink {
  EchoingLogSink(this._sink, {required this._print});

  final LogSink _sink;
  final void Function(String line) _print;

  @override
  void write(String line) {
    _print(line);
    _sink.write(line);
  }

  @override
  Future<void> flush() => _sink.flush();
}
