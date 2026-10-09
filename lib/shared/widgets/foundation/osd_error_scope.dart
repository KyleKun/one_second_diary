import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

/// Reports an error a shared widget caught ([OsdErrorScope]).
typedef OsdErrorReporter =
    void Function(
      String message, {
      required Object error,
      required StackTrace stackTrace,
    });

/// Where shared widgets report the errors they catch from the work they
/// were handed: a failed dialog confirm or snackbar action stays on screen
/// for a retry, and the error goes to the app's log. The app root provides
/// it above the navigator, over `AppLogger`, so dialogs and sheets see it
/// too; without one (a widget test) the error goes to `dart:developer`.
class OsdErrorScope extends InheritedWidget {
  const OsdErrorScope({super.key, required this.onError, required super.child});

  final OsdErrorReporter onError;

  /// The reporter above [context]. Read it before an `await`, while
  /// [context] is still mounted.
  static OsdErrorReporter of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OsdErrorScope>()?.onError ??
      _toDeveloperLog;

  static void _toDeveloperLog(
    String message, {
    required Object error,
    required StackTrace stackTrace,
  }) => developer.log(
    message,
    name: 'osd.ui',
    error: error,
    stackTrace: stackTrace,
  );

  @override
  bool updateShouldNotify(OsdErrorScope oldWidget) =>
      onError != oldWidget.onError;
}
