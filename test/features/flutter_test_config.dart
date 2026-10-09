import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../shared/harness/curved_animation_leaks.dart';

/// Every test under `test/features` fails when it leaves a
/// `CurvedAnimation` undisposed once its widgets are gone: one made in
/// `build` adds a listener to its parent on every rebuild.
/// `parent.drive(CurveTween(curve: …))` needs no disposal.
///
/// flutter_test's own leak tracking (`LeakTesting`) would need
/// `leak_tracker_flutter_testing` as a dev dependency; this tracks the one
/// kind of leak through `FlutterMemoryAllocations`, which debug builds
/// report anyway.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  late CurvedAnimationLeaks leaks;
  setUp(() => leaks = CurvedAnimationLeaks.track());
  tearDown(
    () => expect(
      leaks.madeAt,
      isEmpty,
      reason: 'CurvedAnimations made during the test were never disposed',
    ),
  );
  await testMain();
}
