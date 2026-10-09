import 'package:flutter_test/flutter_test.dart';

/// Waits until [condition] holds, polling every millisecond, and fails the
/// test after [timeout].
///
/// For code that mixes queued work with real file IO (the thumbnail queue,
/// the save flow, the movie builder's clean-up). File IO completes on the
/// VM's IO threads, outside the event loop: no number of
/// `pumpEventQueue` turns is sure to cover it, and `fake_async` cannot
/// advance it. So this is the one helper that waits on the wall clock, and
/// only as a bound: the outcome never depends on time (a passing test
/// returns as soon as the condition holds, typically within milliseconds),
/// and [timeout] only turns a hang into a failure. It stays deterministic
/// under load; a slower machine only waits longer.
Future<void> eventually(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final Stopwatch watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > timeout) fail('Condition not met within $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}
