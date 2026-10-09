import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/clock.dart';

/// A [Clock] pinned to a time the test controls.
///
/// [advance] adds an exact duration, like a real clock: advancing 24 h
/// across a DST change lands at 23:00 or 01:00 local time. Use [setNow] to
/// jump to a wall-clock time.
class FakeClock extends Fake implements Clock {
  FakeClock(DateTime now) : _now = now;

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }

  void setNow(DateTime now) {
    _now = now;
  }
}
