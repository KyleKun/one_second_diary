import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';

/// Writes uncaught errors to the local log, so the "Report error" zip
/// contains them.
///
/// Local only, on purpose: the app promises to work offline and sends
/// nothing by itself, so there is no crash-reporting SDK.
final class GlobalErrorHandlers {
  GlobalErrorHandlers({required this._logger});

  final AppLogger _logger;

  /// Routes `FlutterError.onError` and `PlatformDispatcher.onError` to the
  /// log. Call once in bootstrap, right after the logger exists. The
  /// previous handlers keep running, so debug builds still print errors to
  /// the console and a handler installed earlier still gets its say.
  void install() {
    final FlutterExceptionHandler? previousFlutter = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      onFlutterError(details);
      previousFlutter?.call(details);
    };
    final ErrorCallback? previousPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      final bool handled = onPlatformError(error, stack);
      return (previousPlatform?.call(error, stack) ?? false) || handled;
    };
  }

  /// Logs an error the framework caught (build, layout, paint, gestures).
  void onFlutterError(FlutterErrorDetails details) {
    final DiagnosticsNode? context = details.context;
    _logger.error(
      'FLUTTER',
      'Uncaught error in ${details.library}'
          '${context == null ? '' : ', $context'}',
      error: details.exception,
      stackTrace: details.stack,
    );
  }

  /// Logs an error no zone or future handled. Returns false: logging is not
  /// handling, so the platform still reports it its default way (the
  /// console, logcat), and the app keeps running.
  bool onPlatformError(Object error, StackTrace stackTrace) {
    _logger.error(
      'UNCAUGHT',
      'Uncaught asynchronous error',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  }
}
