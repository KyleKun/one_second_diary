import 'package:flutter_test/flutter_test.dart';

/// Lets the app finish what it is animating: pumps frames [step] apart
/// until none is scheduled, for at most [budget] of fake time. Never fails.
///
/// Use it instead of `pumpAndSettle` in robots and journeys. The real pages
/// run animations that never end on purpose (the Today record halo, the
/// film marquee, spinners and skeleton shimmers while something loads),
/// and `pumpAndSettle` fails on those after ten fake minutes. Here they run
/// for [budget], which covers every finite transition of the design
/// (pushes, sheets, count-ups with their stagger), and the test goes on.
///
/// A snackbar's countdown is an animation too: [budget] is shorter than its
/// 5 s, so it is still up when this returns. Wait it out with
/// `tester.pump(duration)`.
Future<void> settle(
  WidgetTester tester, {
  Duration budget = const Duration(seconds: 2),
  Duration step = const Duration(milliseconds: 100),
}) async {
  await tester.pump();
  Duration elapsed = Duration.zero;
  while (tester.binding.hasScheduledFrame && elapsed < budget) {
    await tester.pump(step);
    elapsed += step;
  }
}

/// Lets the app run until [condition] holds, then settles it ([settle]);
/// fails the test with [reason] when [condition] still does not hold after
/// [timeout] of wall-clock time.
///
/// Real file IO completes on the VM's IO threads, outside the event loop:
/// no number of event-queue turns is sure to cover it. So each round lets
/// the real zone run for a moment, then moves the fake clock on by as much
/// as the wall clock has moved since the last round (one frame, at most
/// [step] later), and checks [condition]:
/// - The fake clock never runs ahead of the wall clock, as on a device. A
///   slower machine takes more rounds, never more fake time, so a
///   snackbar's countdown, a part-of-day timer or a loading delay runs out
///   during the wait only when the wait itself is that long.
/// - What the app does in fake time after the IO (a route's transition, a
///   sheet's hold, a timer) still happens, at the speed of the wall clock.
///
/// Use or check a timed element (a snackbar with Undo) before an IO wait:
/// [settle]'s budget runs once [condition] holds. [timeout] only bounds a
/// failing wait; a passing one returns as soon as [condition] holds.
Future<void> settleUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String reason,
  Duration timeout = const Duration(seconds: 30),
  Duration step = const Duration(milliseconds: 100),
}) async {
  final Stopwatch watch = Stopwatch()..start();
  Duration pumped = Duration.zero;
  // The condition is read between frames, mid-transition too: a robot's
  // reading that throws there (two dates while they cross-fade) is "not
  // yet", and named if the wait runs out.
  Object? lastError;
  bool holds() {
    try {
      return condition();
    } on Object catch (error) {
      lastError = error;
      return false;
    }
  }

  await tester.pump();
  while (!holds()) {
    if (watch.elapsed > timeout) {
      fail(
        'Still waiting after $timeout: $reason'
        '${lastError == null ? '' : ' (last reading: $lastError)'}',
      );
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    final Duration behind = watch.elapsed - pumped;
    final Duration next = behind < step ? behind : step;
    await tester.pump(next);
    pumped += next;
  }
  await settle(tester);
}
