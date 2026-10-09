import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/logging/global_error_handlers.dart';

import '../../support/support.dart';

void main() {
  late MemoryLogSink sink;
  late GlobalErrorHandlers handlers;
  final StackTrace stack = StackTrace.fromString('#0 build (page.dart:9)');

  setUp(() {
    sink = MemoryLogSink();
    handlers = GlobalErrorHandlers(logger: memoryLogger(sink));
  });

  test('logs an uncaught Flutter error with its context and stack, and an '
      'uncaught asynchronous error, leaving its default report to the '
      'platform', () {
    handlers.onFlutterError(
      FlutterErrorDetails(
        exception: StateError('boom'),
        stack: stack,
        library: 'widgets library',
        context: ErrorDescription('while building TodayPage'),
      ),
    );
    final bool handled = handlers.onPlatformError(StateError('late'), stack);

    expect(handled, isFalse);
    expect(sink.lines, <String>[
      '[ERROR] 2024-01-05 10:00:00.000: [FLUTTER] Uncaught error in widgets '
          'library, while building TodayPage\n'
          'Error: Bad state: boom\n'
          'Stacktrace: #0 build (page.dart:9)',
      '[ERROR] 2024-01-05 10:00:00.000: [UNCAUGHT] Uncaught asynchronous '
          'error\n'
          'Error: Bad state: late\n'
          'Stacktrace: #0 build (page.dart:9)',
    ]);
  });

  test('install routes both global hooks to the log and keeps the previous '
      'Flutter handler', () {
    final FlutterExceptionHandler? originalFlutter = FlutterError.onError;
    final ErrorCallback? originalPlatform = PlatformDispatcher.instance.onError;
    final List<FlutterErrorDetails> presented = <FlutterErrorDetails>[];
    FlutterError.onError = presented.add;
    try {
      handlers.install();
      final FlutterErrorDetails details = FlutterErrorDetails(
        exception: StateError('boom'),
        stack: stack,
      );

      FlutterError.onError!(details);
      PlatformDispatcher.instance.onError!(StateError('late'), stack);

      expect(presented, <FlutterErrorDetails>[details]);
      expect(sink.lines.map((String line) => line.split('\n').first), <String>[
        '[ERROR] 2024-01-05 10:00:00.000: [FLUTTER] Uncaught error in '
            'Flutter framework',
        '[ERROR] 2024-01-05 10:00:00.000: [UNCAUGHT] Uncaught asynchronous '
            'error',
      ]);
    } finally {
      FlutterError.onError = originalFlutter;
      PlatformDispatcher.instance.onError = originalPlatform;
    }
  });
}
