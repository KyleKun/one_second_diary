import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/progress_throttle.dart';

import '../../support/support.dart';

void main() {
  // At most 10 progress events a second.
  test('lets the first event through, then drops events closer than 100 ms '
      'to the last one it let through', () {
    final FakeClock clock = FakeClock(DateTime(2024, 1, 5, 10));
    final ProgressThrottle throttle = ProgressThrottle(clock: clock);
    final List<bool> passed = <bool>[throttle.tryPass()];

    for (final int ms in <int>[40, 59, 1, 150, 99, 1]) {
      clock.advance(Duration(milliseconds: ms));
      passed.add(throttle.tryPass());
    }

    // t = 0, 40, 99, 100, 250, 349, 350
    expect(passed, <bool>[true, false, false, true, true, false, true]);
  });
}
