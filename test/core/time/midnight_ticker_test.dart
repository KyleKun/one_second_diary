import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';

import '../../support/support.dart';

void main() {
  test('emits the new day at each local midnight, one day per midnight', () {
    fakeAsync((FakeAsync async) {
      final FakeClock clock = FakeClock(DateTime(2026, 1, 10, 23, 59));
      final MidnightTicker ticker = MidnightTicker(clock: clock);
      final List<LocalDay> days = <LocalDay>[];
      final StreamSubscription<LocalDay> subscription = ticker.days.listen(
        days.add,
      );

      clock.advance(const Duration(minutes: 1));
      async.elapse(const Duration(minutes: 1));
      expect(days, <LocalDay>[LocalDay(2026, 1, 11)]);

      for (int minute = 0; minute < 2 * 24 * 60; minute++) {
        clock.advance(const Duration(minutes: 1));
        async.elapse(const Duration(minutes: 1));
      }

      expect(days, <LocalDay>[
        LocalDay(2026, 1, 11),
        LocalDay(2026, 1, 12),
        LocalDay(2026, 1, 13),
      ]);
      unawaited(subscription.cancel());
    });
  });

  test(
    'check() on resume catches a day change the suspended timer missed, '
    'once (v1.7 kept showing yesterday until the process died, C 3.2 #1)',
    () {
      fakeAsync((FakeAsync async) {
        final FakeClock clock = FakeClock(DateTime(2026, 1, 10, 23, 59));
        final MidnightTicker ticker = MidnightTicker(clock: clock);
        final List<LocalDay> days = <LocalDay>[];
        final StreamSubscription<LocalDay> subscription = ticker.days.listen(
          days.add,
        );

        // Suspended for 30 hours: the wall clock moved, the timer did not.
        clock.advance(const Duration(hours: 30));
        ticker.check();
        async.flushMicrotasks();
        // The stale timer fires on resume.
        async.elapse(const Duration(minutes: 1));

        expect(days, <LocalDay>[LocalDay(2026, 1, 12)]);
        expect(ticker.today, LocalDay(2026, 1, 12));
        unawaited(subscription.cancel());
      });
    },
  );

  test('after a resume, the next midnight is still on time', () {
    fakeAsync((FakeAsync async) {
      final FakeClock clock = FakeClock(DateTime(2026, 1, 10, 0, 1));
      final MidnightTicker ticker = MidnightTicker(clock: clock);
      final List<LocalDay> days = <LocalDay>[];
      final StreamSubscription<LocalDay> subscription = ticker.days.listen(
        days.add,
      );

      // Suspended for 30 hours; the timer still waits for its 24 hours.
      clock.advance(const Duration(hours: 30)); // 2026-01-11 06:01
      ticker.check();
      clock.advance(const Duration(hours: 18)); // 2026-01-12 00:01
      async.elapse(const Duration(hours: 18));

      expect(days, <LocalDay>[LocalDay(2026, 1, 11), LocalDay(2026, 1, 12)]);
      unawaited(subscription.cancel());
    });
  });

  test('never goes back a day (a fall-back that repeats midnight, or the '
      'clock set back)', () {
    fakeAsync((FakeAsync async) {
      final FakeClock clock = FakeClock(DateTime(2026, 1, 10, 23, 59));
      final MidnightTicker ticker = MidnightTicker(clock: clock);
      final List<LocalDay> days = <LocalDay>[];
      final StreamSubscription<LocalDay> subscription = ticker.days.listen(
        days.add,
      );
      clock.advance(const Duration(minutes: 2));
      async.elapse(const Duration(minutes: 2));

      clock.setNow(DateTime(2026, 1, 10, 23, 30));
      ticker.check();
      async.flushMicrotasks();

      expect(days, <LocalDay>[LocalDay(2026, 1, 11)]);
      expect(ticker.today, LocalDay(2026, 1, 11));
      unawaited(subscription.cancel());
    });
  });

  // Needs a zone where one local midnight of 2026 does not exist.
  final LocalDay? gapDay = _firstDayWithoutMidnight(2026);
  test(
    'a day that starts at 01:00 (no midnight: a DST gap) still ticks',
    () {
      fakeAsync((FakeAsync async) {
        final LocalDay day = gapDay!;
        final DateTime lastMinute = DateTime(
          day.year,
          day.month,
          day.day - 1,
          23,
          59,
        );
        final FakeClock clock = FakeClock(lastMinute);
        final MidnightTicker ticker = MidnightTicker(clock: clock);
        final List<LocalDay> days = <LocalDay>[];
        final StreamSubscription<LocalDay> subscription = ticker.days.listen(
          days.add,
        );

        clock.advance(const Duration(minutes: 1)); // 01:00 of the new day
        async.elapse(const Duration(minutes: 1));

        expect(days, <LocalDay>[day]);
        unawaited(subscription.cancel());
      });
    },
    skip: gapDay == null
        ? 'needs a zone with a midnight DST gap, e.g. TZ=America/Santiago'
        : false,
  );
}

/// The first day of [year] whose local midnight does not exist in the
/// test's time zone, or null.
LocalDay? _firstDayWithoutMidnight(int year) {
  for (
    DateTime day = DateTime(year);
    day.year == year;
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    if (day.hour != 0) return LocalDay(day.year, day.month, day.day);
  }
  return null;
}
