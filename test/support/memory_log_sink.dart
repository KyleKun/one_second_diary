import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/log_sink.dart';

import 'fake_clock.dart';

/// A [LogSink] that keeps every line in memory, for assertions on what was
/// logged. The lines are the real ones `AppLogger` formats, e.g.
/// `[INFO] 2024-01-05 10:00:00.000: [PREFERENCES] verboseLogging: true`.
///
/// [lines] holds everything written; [flushedLines] holds what was written
/// before the last `flush`, i.e. what a zip made after it would contain.
class MemoryLogSink extends Fake implements LogSink {
  final List<String> lines = <String>[];
  List<String> flushedLines = const <String>[];

  @override
  void write(String line) => lines.add(line);

  @override
  Future<void> flush() async {
    flushedLines = List<String>.unmodifiable(lines);
  }
}

/// A real [AppLogger] writing into [sink], for tests of code that logs.
/// [clock] defaults to 2024-01-05 10:00 local time; verbose lines are kept
/// unless [verbose] is false.
AppLogger memoryLogger(
  MemoryLogSink sink, {
  Clock? clock,
  bool verbose = true,
}) => AppLogger(
  sink: sink,
  clock: clock ?? FakeClock(DateTime(2024, 1, 5, 10)),
  isVerboseEnabled: () => verbose,
);
