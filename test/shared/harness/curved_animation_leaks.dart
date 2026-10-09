import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The [CurvedAnimation]s made while a test runs that were never disposed.
///
/// A [CurvedAnimation] adds a status listener to its parent and keeps it
/// until it is disposed, so one made in `build` leaks a listener on every
/// rebuild (Flutter's documentation: "Do not recreate it on every build").
/// `parent.drive(CurveTween(curve: …))` needs no disposal. Start tracking
/// before the widgets are built; the tracking ends with the test.
final class CurvedAnimationLeaks {
  CurvedAnimationLeaks.track() {
    FlutterMemoryAllocations.instance.addListener(_on);
    addTearDown(() => FlutterMemoryAllocations.instance.removeListener(_on));
  }

  /// Each live one, with where it was made.
  final Map<Object, StackTrace> _live = Map<Object, StackTrace>.identity();

  /// How many were made and are not disposed yet.
  int get undisposed => _live.length;

  /// Where the undisposed ones were made: the first frames of this app's
  /// code in each creation's stack.
  List<String> get madeAt => <String>[
    for (final StackTrace made in _live.values)
      made
          .toString()
          .split('\n')
          .where((String frame) => frame.contains('package:one_second_diary/'))
          .take(3)
          .join(' <- '),
  ];

  void _on(ObjectEvent event) {
    if (event.object is! CurvedAnimation) return;
    switch (event) {
      case ObjectCreated():
        _live[event.object] = StackTrace.current;
      case ObjectDisposed():
        _live.remove(event.object);
      case ObjectEvent():
        break;
    }
  }
}
