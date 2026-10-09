import 'dart:async';

import 'package:flutter/widgets.dart';

/// The app's lifecycle as a stream, for services that are not widgets (the
/// `LibraryWiring` rescans on resume and saves on pause).
///
/// Built after the first frame, when the post-frame launch asks for the
/// library wiring (the DI container creates it lazily); its
/// `AppLifecycleListener` needs the binding.
final class AppLifecycleStates {
  AppLifecycleStates() {
    _listener = AppLifecycleListener(onStateChange: _states.add);
  }

  final StreamController<AppLifecycleState> _states =
      StreamController<AppLifecycleState>.broadcast();
  late final AppLifecycleListener _listener;

  /// Every state the app goes through, including the steps between two
  /// reported states (resumed → inactive → hidden → paused).
  Stream<AppLifecycleState> get states => _states.stream;

  Future<void> dispose() {
    _listener.dispose();
    return _states.close();
  }
}
