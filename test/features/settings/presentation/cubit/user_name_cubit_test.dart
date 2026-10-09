import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/user_name_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/user_name_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/support.dart';
import '../../../../support/track_1c/refusing_shared_preferences.dart';

// An optional name, set in onboarding and in the Settings "Your name"
// sheet, read by every greeting (Today) and the saved snackbar.
void main() {
  test('no name at first (every greeting takes its variant without one); '
      'the name is stored trimmed, a blank one clears it, the name is never '
      'logged, and the cubit follows the stored name whoever changes it '
      '(O4 writes it too)', () async {
    final SettingsRepository settings = SettingsRepository(
      prefs: await openLegacyPrefs(legacyPrefs()),
    );
    final MemoryLogSink log = MemoryLogSink();
    final UserNameCubit cubit = UserNameCubit(
      settings: settings,
      logger: memoryLogger(log),
    );
    addTearDown(cubit.close);
    expect(cubit.state, const UserNameState(name: ''));

    await cubit.rename('  Ana Luísa ');

    expect(cubit.state, const UserNameState(name: 'Ana Luísa'));
    expect(
      (await SharedPreferences.getInstance()).getString('userName'),
      'Ana Luísa',
    );
    expect(log.lines, isNotEmpty);
    expect(log.lines.join('\n'), isNot(contains('Ana')));

    await cubit.rename('   ');

    expect(cubit.state, const UserNameState(name: ''));

    await settings.userName.set('Kyle');
    await pumpEventQueue();

    expect(cubit.state.name, 'Kyle');
  });

  test('keeps the name and says so on every refusal to store it', () async {
    final (PrefsStore store, _) = await openRefusingPrefs(
      legacyPrefs(extra: <String, Object>{'userName': 'Kyle'}),
      refused: <String>{'userName'},
    );
    final UserNameCubit cubit = UserNameCubit(
      settings: SettingsRepository(prefs: store),
      logger: memoryLogger(MemoryLogSink()),
    );
    addTearDown(cubit.close);
    expect(cubit.state.name, 'Kyle');
    final List<UserNameStatus> statuses = <UserNameStatus>[];
    cubit.stream.listen((UserNameState state) => statuses.add(state.status));

    await cubit.rename('Ana');
    await cubit.rename('Ana');
    await pumpEventQueue();

    expect(cubit.state.name, 'Kyle');
    expect(statuses, <UserNameStatus>[
      UserNameStatus.saving,
      UserNameStatus.saveFailed,
      UserNameStatus.saving,
      UserNameStatus.saveFailed,
    ]);
  });
}
