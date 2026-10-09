import 'package:one_second_diary/core/platform/clock.dart';

/// Keeps a job's progress reports to at most 10 per second, so a burst of
/// statistics samples or of quick movie steps never floods the UI with
/// rebuilds.
///
/// Leading edge: the first event passes, then each event at least
/// [minInterval] after the last one that passed. Time comes from the
/// injected [Clock], so tests drive it with a `FakeClock`.
final class ProgressThrottle {
  ProgressThrottle({required this._clock});

  /// The shortest gap between two events that pass: 10 per second.
  static const Duration minInterval = Duration(milliseconds: 100);

  final Clock _clock;
  DateTime? _lastPassed;

  /// Whether an event happening now may be reported. Records it when it may.
  bool tryPass() {
    final DateTime now = _clock.now();
    final DateTime? last = _lastPassed;
    if (last != null && now.difference(last) < minInterval) return false;
    _lastPassed = now;
    return true;
  }
}
