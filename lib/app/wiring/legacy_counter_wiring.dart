import 'dart:async';

import 'package:one_second_diary/app/wiring/active_profile_clips.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/storage/legacy_prefs_mirror.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';

/// Keeps the clip counters older versions read (`videoCount`,
/// `dailyEntry`, `today`) true for the whole session, so a downgrade finds
/// them: written from the active profile's snapshot each time it changes,
/// on a profile switch and at midnight.
///
/// Nothing here throws: a refused write is logged.
class LegacyCounterWiring {
  LegacyCounterWiring({
    required this._activeClips,
    required this._mirror,
    required this._midnight,
    required this._clock,
    required this._logger,
  });

  final ActiveProfileClips _activeClips;
  final LegacyPrefsMirror _mirror;
  final MidnightTicker _midnight;
  final Clock _clock;
  final AppLogger _logger;

  static const String _tag = 'APP';

  StreamSubscription<LocalDay>? _days;

  /// The tail of the writes in flight: they run one at a time, so the last
  /// state is what stays stored.
  Future<void> _writes = Future<void>.value();

  /// Follows the active profile's snapshots and the day.
  void start() {
    _activeClips.listen(
      ({required ClipIndex? previous, required bool switched}) => _write(),
    );
    // `today` and `dailyEntry` roll over with the day.
    _days = _midnight.days.listen((_) => _write());
  }

  /// Stops following, and waits for the writes in flight.
  Future<void> dispose() async {
    await _days?.cancel();
    await _activeClips.dispose();
    await _writes;
  }

  /// Writes the counters from the active profile's snapshot, once there is
  /// one.
  void _write() {
    final ClipIndex? index = _activeClips.index;
    if (index == null) return;
    final LocalDay today = LocalDay.fromDateTime(_clock.now());
    _writes = _writes.then((_) async {
      try {
        await _mirror.writeClipCounters(
          daysRecorded: index.dayCount,
          todayRecorded: index.hasDay(today),
          today: today,
        );
      } on Object catch (error, stackTrace) {
        _logger.error(
          _tag,
          'Could not write the legacy clip counters',
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
  }
}
