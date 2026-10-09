import 'dart:async';

import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/time/local_day.dart';

/// Tells when the local day changes, so Today, the `today` / `dailyEntry`
/// preferences and anything else keyed on "today" roll over while the app
/// stays open.
///
/// [days] emits the new day at each local midnight. Timers do not run while
/// the app is suspended, so the app also calls [check] when it resumes.
/// The day only moves forward: a DST fall-back that repeats midnight, or a
/// clock set back, never emits an earlier day.
final class MidnightTicker {
  MidnightTicker({required this._clock})
    : _today = LocalDay.fromDateTime(_clock.now()) {
    _controller = StreamController<LocalDay>.broadcast(
      onListen: _arm,
      onCancel: _disarm,
    );
  }

  final Clock _clock;
  late final StreamController<LocalDay> _controller;
  Timer? _timer;
  LocalDay _today;

  /// The new day, once per day change (a broadcast stream). A timer runs
  /// only while someone listens.
  Stream<LocalDay> get days => _controller.stream;

  /// The latest day seen.
  LocalDay get today => _today;

  /// Emits the new day if it changed since the last one, and re-aims the
  /// midnight timer (a timer set before a suspension waits for its full
  /// duration of awake time).
  void check() {
    final LocalDay day = LocalDay.fromDateTime(_clock.now());
    if (day.isAfter(_today)) {
      _today = day;
      _controller.add(day);
    }
    if (_controller.hasListener) _arm();
  }

  /// A midnight inside a DST gap (Santiago's) resolves to the first time
  /// after it, so the timer still fires on the new day.
  void _arm() {
    _timer?.cancel();
    final DateTime now = _clock.now();
    final DateTime midnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(midnight.difference(now), check);
  }

  void _disarm() {
    _timer?.cancel();
    _timer = null;
  }
}
