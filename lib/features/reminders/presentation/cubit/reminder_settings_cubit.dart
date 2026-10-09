import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/permissions/access_outcome.dart';
import 'package:one_second_diary/core/permissions/permission_feature.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/features/reminders/presentation/cubit/reminder_settings_state.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/domain/reminder_time.dart';

/// The daily reminder's settings, over their keys in [SettingsRepository].
///
/// It only stores the choices: `ReminderPlanWiring` re-plans the reminders on
/// every change. The state follows the stored values (`Setting.changes`), so
/// the two pages' instances never disagree.
///
/// The notification permission is asked only when the user turns the reminder
/// on; a refusal leaves the switch off.
class ReminderSettingsCubit extends Cubit<ReminderSettingsState> {
  ReminderSettingsCubit({
    required SettingsRepository settings,
    required this._permissions,
    required this._logger,
  }) : _settings = settings,
       super(
         ReminderSettingsState(
           enabled: settings.remindersEnabled.value,
           persistent: settings.persistentReminder.value,
           time: settings.reminderTime.value,
         ),
       ) {
    _subscriptions = <StreamSubscription<Object?>>[
      settings.remindersEnabled.changes.listen(
        (bool enabled) => emit(state.copyWith(enabled: enabled)),
      ),
      settings.persistentReminder.changes.listen(
        (bool persistent) => emit(state.copyWith(persistent: persistent)),
      ),
      settings.reminderTime.changes.listen(
        (ReminderTime time) => emit(state.copyWith(time: time)),
      ),
    ];
  }

  final SettingsRepository _settings;
  final PermissionRequester _permissions;
  final AppLogger _logger;
  late final List<StreamSubscription<Object?>> _subscriptions;

  static const String _tag = 'NOTIFICATIONS';

  /// Reads whether the phone lets the app post notifications, without
  /// asking (never a prompt): when the page opens and when the app comes
  /// back from the phone's settings. Only while the user wants the
  /// reminder (it is on, or they just asked for it): otherwise nothing
  /// depends on it and the platform is left alone.
  Future<void> checkAccess() async {
    if (!state.enabled && !state.refused) return;
    final AccessOutcome access = await _permissions.check(
      PermissionFeature.reminders,
    );
    if (!isClosed) emit(state.copyWith(access: access));
  }

  /// The "Daily reminder" switch. Turning it on asks for the permission
  /// first; it is stored only once the phone allows it.
  Future<void> setEnabled(bool enabled) async {
    if (!enabled) {
      await _store(
        () => _settings.remindersEnabled.set(false),
        success: 'Notifications were disabled',
        after: (ReminderSettingsState s) =>
            s.copyWith(enabled: false, refused: false),
      );
      return;
    }
    emit(state.copyWith(status: ReminderSettingsStatus.requesting));
    final AccessOutcome access = await _permissions.request(
      PermissionFeature.reminders,
    );
    if (isClosed) return;
    if (access != AccessOutcome.granted) {
      _logger.info(_tag, 'Notifications were not enabled: ${access.name}');
      emit(
        state.copyWith(
          access: access,
          refused: true,
          status: ReminderSettingsStatus.ready,
        ),
      );
      return;
    }
    emit(state.copyWith(access: access));
    await _store(
      () => _settings.remindersEnabled.set(true),
      success: 'Notifications were enabled',
      after: (ReminderSettingsState s) =>
          s.copyWith(enabled: true, refused: false),
    );
  }

  /// The blocked banner's "Open settings": the app's page in the phone's
  /// settings, where notifications can be allowed. The page checks again
  /// when the app comes back ([checkAccess]).
  Future<void> openSystemSettings() => _permissions.openSettings();

  /// "Persistent notification" (Android only).
  Future<void> setPersistent(bool persistent) => _store(
    () => _settings.persistentReminder.set(persistent),
    success:
        'Persistent notifications were ${persistent ? 'enabled' : 'disabled'}',
    after: (ReminderSettingsState s) => s.copyWith(persistent: persistent),
  );

  /// The reminder time, from the time sheet.
  Future<void> setTime(ReminderTime time) => _store(
    () => _settings.reminderTime.set(time),
    success:
        'Reminder time set to ${_twoDigits(time.hour)}:'
        '${_twoDigits(time.minute)}',
    after: (ReminderSettingsState s) => s.copyWith(time: time),
  );

  /// Stores a change: [saving] first, so every refusal is a new
  /// transition to [ReminderSettingsStatus.saveFailed].
  Future<void> _store(
    Future<void> Function() write, {
    required String success,
    required ReminderSettingsState Function(ReminderSettingsState) after,
  }) async {
    emit(state.copyWith(status: ReminderSettingsStatus.saving));
    try {
      await write();
    } on StorageException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not store the reminder settings',
        error: error,
        stackTrace: stackTrace,
      );
      if (!isClosed) {
        emit(state.copyWith(status: ReminderSettingsStatus.saveFailed));
      }
      return;
    }
    // Bug reports rely on this wording (`[NOTIFICATIONS] - Notifications
    // were enabled`).
    _logger.info(_tag, '- $success');
    if (!isClosed) {
      emit(after(state).copyWith(status: ReminderSettingsStatus.ready));
    }
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');

  @override
  Future<void> close() async {
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
