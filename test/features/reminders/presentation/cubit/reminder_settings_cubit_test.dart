// The daily reminder's switch, time and persistence, over its four keys.
// The permission is asked only when the user turns the reminder on.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/permissions/access_outcome.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/reminders/presentation/cubit/reminder_settings_cubit.dart';
import 'package:one_second_diary/features/reminders/presentation/cubit/reminder_settings_state.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../../../support/support.dart';
import '../../../../support/track_1c/refusing_shared_preferences.dart';

void main() {
  late SettingsRepository settings;
  late FakePermissionGateway permissions;
  late MemoryLogSink log;

  Future<ReminderSettingsCubit> cubitOver(Map<String, Object> prefs) async {
    final PrefsStore store = await openLegacyPrefs(prefs);
    settings = SettingsRepository(prefs: store);
    permissions = FakePermissionGateway();
    log = MemoryLogSink();
    final ReminderSettingsCubit cubit = ReminderSettingsCubit(
      settings: settings,
      permissions: PermissionRequester(
        permissions: permissions,
        deviceInfo: FakeDeviceInfoGateway(),
        logger: memoryLogger(log),
      ),
      logger: memoryLogger(log),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('asks for the notification permission, then stores the switch and '
      'logs it as v1.7 did; refused, the switch shows on while the system '
      'asks and goes back off with the blocked explanation', () async {
    final ReminderSettingsCubit cubit = await cubitOver(legacyPrefs());

    await cubit.setEnabled(true);

    expect(permissions.requestedTogether, <Set<AppPermission>>[
      <AppPermission>{AppPermission.notifications},
    ]);
    expect(settings.remindersEnabled.value, isTrue);
    expect(
      cubit.state,
      const ReminderSettingsState(
        enabled: true,
        persistent: false,
        time: (hour: 20, minute: 0),
        access: AccessOutcome.granted,
      ),
    );
    expect(
      log.lines,
      contains(endsWith('[NOTIFICATIONS] - Notifications were enabled')),
    );

    final ReminderSettingsCubit refused = await cubitOver(legacyPrefs());
    permissions.answers[AppPermission.notifications] =
        AppPermissionStatus.denied;
    final List<ReminderSettingsState> states = <ReminderSettingsState>[];
    refused.stream.listen(states.add);

    await refused.setEnabled(true);

    expect(states.first.switchOn, isTrue);
    expect(refused.state.switchOn, isFalse);
    expect(refused.state.enabled, isFalse);
    expect(refused.state.blocked, isTrue);
    expect(refused.state.summary, ReminderSummary.off);
    expect(settings.remindersEnabled.value, isFalse);
    expect(log.lines, isNot(contains(endsWith('Notifications were enabled'))));
  });

  test('the permission is checked on opening and back from the phone '
      'settings, never prompted: a reminder the phone blocks says so until '
      'allowed there; nothing is checked while the reminder is off; turning '
      'it off asks nothing, logs it as v1.7 did and drops the explanation; '
      '"Open settings" opens the app\'s page in the phone settings', () async {
    final ReminderSettingsCubit off = await cubitOver(legacyPrefs());
    permissions.statuses[AppPermission.notifications] =
        AppPermissionStatus.permanentlyDenied;

    await off.checkAccess();

    expect(off.state.access, isNull);
    expect(off.state.blocked, isFalse);

    final ReminderSettingsCubit cubit = await cubitOver(
      legacyPrefs(extra: <String, Object>{'activatedNotification': true}),
    );
    permissions.statuses[AppPermission.notifications] =
        AppPermissionStatus.permanentlyDenied;

    await cubit.checkAccess();

    expect(cubit.state.access, AccessOutcome.blocked);
    expect(cubit.state.summary, ReminderSummary.blocked);

    permissions.statuses[AppPermission.notifications] =
        AppPermissionStatus.granted;
    await cubit.checkAccess();

    expect(cubit.state.summary, ReminderSummary.on);
    expect(cubit.state.blocked, isFalse);

    permissions.statuses[AppPermission.notifications] =
        AppPermissionStatus.permanentlyDenied;
    await cubit.checkAccess();
    await cubit.openSystemSettings();
    await cubit.setEnabled(false);

    expect(permissions.settingsOpened, isTrue);
    expect(permissions.requestedTogether, isEmpty);
    expect(settings.remindersEnabled.value, isFalse);
    expect(cubit.state.blocked, isFalse);
    expect(cubit.state.summary, ReminderSummary.off);
    expect(
      log.lines,
      contains(endsWith('[NOTIFICATIONS] - Notifications were disabled')),
    );
  });

  test('shows the stored switch, time and persistence and follows them, '
      'whoever changes them (S1 and S2 each have one); a new time and '
      '"Persistent notification" are stored and logged as v1.7 did', () async {
    final ReminderSettingsCubit cubit = await cubitOver(
      legacyPrefs(
        extra: <String, Object>{
          'activatedNotification': true,
          'persistentNotification': true,
          'scheduledTimeHour': 7,
          'scheduledTimeMinute': 30,
        },
      ),
    );
    expect(
      cubit.state,
      const ReminderSettingsState(
        enabled: true,
        persistent: true,
        time: (hour: 7, minute: 30),
      ),
    );

    await settings.reminderTime.set((hour: 6, minute: 45));
    await settings.persistentReminder.set(false);
    await pumpEventQueue();

    expect(cubit.state.time, (hour: 6, minute: 45));
    expect(cubit.state.persistent, isFalse);

    await cubit.setTime((hour: 7, minute: 5));
    await cubit.setPersistent(true);
    await cubit.setPersistent(false);

    expect(settings.reminderTime.value, (hour: 7, minute: 5));
    expect(cubit.state.time, (hour: 7, minute: 5));
    expect(settings.persistentReminder.value, isFalse);
    expect(
      log.lines.map((String line) => line.split(': ').skip(1).join(': ')),
      <String>[
        '[NOTIFICATIONS] - Reminder time set to 07:05',
        '[NOTIFICATIONS] - Persistent notifications were enabled',
        '[NOTIFICATIONS] - Persistent notifications were disabled',
      ],
    );
  });

  test('a change the phone refuses to store changes nothing, and each '
      'refusal is reported again', () async {
    final (PrefsStore store, _) = await openRefusingPrefs(
      legacyPrefs(extra: <String, Object>{'activatedNotification': true}),
      refused: <String>{'scheduledTimeHour', 'persistentNotification'},
    );
    settings = SettingsRepository(prefs: store);
    final MemoryLogSink log = MemoryLogSink();
    final ReminderSettingsCubit cubit = ReminderSettingsCubit(
      settings: settings,
      permissions: PermissionRequester(
        permissions: FakePermissionGateway(),
        deviceInfo: FakeDeviceInfoGateway(),
        logger: memoryLogger(log),
      ),
      logger: memoryLogger(log),
    );
    addTearDown(cubit.close);
    final List<ReminderSettingsStatus> statuses = <ReminderSettingsStatus>[];
    cubit.stream.listen((ReminderSettingsState s) => statuses.add(s.status));

    await cubit.setTime((hour: 6, minute: 0));
    await cubit.setPersistent(true);
    await pumpEventQueue();

    expect(statuses, <ReminderSettingsStatus>[
      ReminderSettingsStatus.saving,
      ReminderSettingsStatus.saveFailed,
      ReminderSettingsStatus.saving,
      ReminderSettingsStatus.saveFailed,
    ]);
    expect(cubit.state.time, (hour: 20, minute: 0));
    expect(cubit.state.persistent, isFalse);
    expect(log.lines, contains(contains('[NOTIFICATIONS] Could not store')));
  });
}
