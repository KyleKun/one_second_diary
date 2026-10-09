import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';

import '../../support/support.dart';

void main() {
  late MemoryLogSink sink;
  late FakeClock clock;

  setUp(() {
    sink = MemoryLogSink();
    clock = FakeClock(DateTime(2024, 1, 5, 20, 30, 15, 250));
  });

  AppLogger logger({bool verbose = false}) =>
      AppLogger(sink: sink, clock: clock, isVerboseEnabled: () => verbose);

  test('writes v1.7 lines: [LEVEL] local time: [TAG] message, with the '
      'error and the stack trace on lines of their own', () {
    logger()
      ..info('PREFERENCES', 'verboseLogging: true')
      ..warning('ffmpeg', 'slow')
      ..error('SAVE', 'failed')
      ..error(
        'SAVE',
        'publish failed',
        error: StateError('disk full'),
        stackTrace: StackTrace.fromString('#0 main (a.dart:1)'),
      );

    expect(sink.lines, <String>[
      '[INFO] 2024-01-05 20:30:15.250: [PREFERENCES] verboseLogging: true',
      '[WARNING] 2024-01-05 20:30:15.250: [ffmpeg] slow',
      '[ERROR] 2024-01-05 20:30:15.250: [SAVE] failed',
      '[ERROR] 2024-01-05 20:30:15.250: [SAVE] publish failed\n'
          'Error: Bad state: disk full\n'
          'Stacktrace: #0 main (a.dart:1)',
    ]);
  });

  test('writes verbose lines only while verbose logging is on', () {
    bool verbose = false;
    final AppLogger log = AppLogger(
      sink: sink,
      clock: clock,
      isVerboseEnabled: () => verbose,
    );

    log.verbose('CALENDAR', 'lat 35.71');
    verbose = true;
    log.verbose('CALENDAR', 'lat 35.72');

    expect(sink.lines, <String>[
      '[VERBOSE] 2024-01-05 20:30:15.250: [CALENDAR] lat 35.72',
    ]);
  });

  test('flush puts every line so far on disk, for the bug report', () async {
    final AppLogger log = logger()..info('SETTINGS', 'Report error tapped');

    await log.flush();
    log.info('SETTINGS', 'zipping');

    expect(sink.flushedLines, <String>[
      '[INFO] 2024-01-05 20:30:15.250: [SETTINGS] Report error tapped',
    ]);
  });
}
