import 'dart:async';

import 'package:one_second_diary/app/wiring/active_profile_clips.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/notification_channel_text.dart';
import 'package:one_second_diary/core/platform/notification_tap.dart';
import 'package:one_second_diary/core/platform/notifications_gateway.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/reminders/data/reminder_scheduler.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_planner.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_text.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

/// Keeps the reminders planned for the whole session, and hands every
/// reminder tap on.
///
/// `ReminderScheduler.replan` runs after the notification plugin is
/// initialised, then on each change of the reminder settings, of a
/// recorded day the plan covers, of the active profile, and of the
/// language ([localeChanged]). Nothing is planned before `initialize()`.
/// The Android channel is named in the app's language at `initialize()`
/// and renamed on each language change.
///
/// Nothing here throws: the scheduler logs its own failures, and a failed
/// rename is logged here.
class ReminderPlanWiring {
  /// [reminderText] gives the reminder's title and body, and
  /// [channelText] the Android channel's name and description, in the app's
  /// current language (`Strings`); the reminders layer never localises.
  /// [activeClips] gives the active profile's recorded days.
  /// [onNotificationTap] receives every reminder tap, including the one
  /// that launched the app.
  ReminderPlanWiring({
    required this._notifications,
    required this._reminders,
    required this._reminderText,
    required this._channelText,
    required this._settings,
    required this._activeClips,
    required this._clock,
    required this._logger,
    required this._onNotificationTap,
  });

  final NotificationsGateway _notifications;
  final ReminderScheduler _reminders;
  final ReminderText Function() _reminderText;
  final NotificationChannelText Function() _channelText;
  final SettingsRepository _settings;
  final ActiveProfileClips _activeClips;
  final Clock _clock;
  final AppLogger _logger;
  final void Function(NotificationTap tap) _onNotificationTap;

  static const String _tag = 'APP';

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  /// Whether the notification plugin is initialised: nothing is planned
  /// before.
  bool _notificationsReady = false;

  /// Follows reminder taps, then initialises the notification plugin (the
  /// tap that launched the app arrives at the end of `initialize()`, so the
  /// subscription comes first), then plans the reminders and follows what
  /// they depend on.
  Future<void> start() async {
    _subscriptions.add(_notifications.taps.listen(_onNotificationTap));
    _activeClips.listen(_activeClipsChanged);
    await _notifications.initialize(channel: _channelText());
    _notificationsReady = true;
    _replan();
    for (final Stream<Object?> change in <Stream<Object?>>[
      _settings.remindersEnabled.changes,
      _settings.persistentReminder.changes,
      _settings.reminderTime.changes,
    ]) {
      _subscriptions.add(change.listen((_) => _replan()));
    }
  }

  /// The app shows another language: renames the Android channel and
  /// re-plans the reminders so their text follows it. Call it once the new
  /// locale is applied, since the text is read in the current language.
  void localeChanged() {
    _renameChannel();
    _replan();
  }

  Future<void> dispose() async {
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _activeClips.dispose();
  }

  /// Another profile, or its first snapshot, or a recorded day the plan
  /// covers.
  void _activeClipsChanged({
    required ClipIndex? previous,
    required bool switched,
  }) {
    final ClipIndex? index = _activeClips.index;
    if (switched ||
        previous == null ||
        index == null ||
        _plannedDaysDiffer(previous, index)) {
      _replan();
    }
  }

  /// Whether a day the reminders are planned for is recorded in one
  /// snapshot and not in the other. The window reaches one day further on
  /// each side, in case the device zone the planner uses disagrees with the
  /// clock about today.
  bool _plannedDaysDiffer(ClipIndex before, ClipIndex after) {
    final LocalDay today = LocalDay.fromDateTime(_clock.now());
    for (int offset = -1; offset <= ReminderPlanner.windowDays; offset++) {
      final LocalDay day = today.addDays(offset);
      if (before.hasDay(day) != after.hasDay(day)) return true;
    }
    return false;
  }

  /// Names the Android channel in the current language, once the plugin is
  /// initialised (it is named then too). Not awaited.
  void _renameChannel() {
    if (_notificationsReady) unawaited(_updateChannel());
  }

  Future<void> _updateChannel() async {
    try {
      await _notifications.updateChannel(_channelText());
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not rename the reminder channel',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Re-plans the reminders with the text in the current language and the
  /// active profile's recorded days as they are now. Not awaited: the
  /// scheduler runs re-plans one at a time, never throws, and the last one
  /// wins.
  void _replan() {
    if (!_notificationsReady) return;
    final ClipIndex? index = _activeClips.index;
    unawaited(
      _reminders.replan(
        text: _reminderText(),
        isRecorded: (LocalDay day) => index?.hasDay(day) ?? false,
      ),
    );
  }
}
