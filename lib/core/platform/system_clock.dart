import 'package:one_second_diary/core/platform/clock.dart';

/// The real [Clock]: the device's local wall-clock time.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
