import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/theme_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/support.dart';
import '../../../../support/track_1c/refusing_shared_preferences.dart';

void main() {
  test('shows the stored theme (an install without the key is dark, D15); '
      'the Settings switch stores it; it follows the stored theme, whoever '
      'changes it', () async {
    final SettingsRepository settings = SettingsRepository(
      prefs: await openLegacyPrefs(legacyPrefs()),
    );
    final ThemeCubit cubit = ThemeCubit(
      settings: settings,
      logger: memoryLogger(MemoryLogSink()),
    );
    addTearDown(cubit.close);
    expect(cubit.state.darkMode, isTrue);

    await cubit.setDarkMode(false);
    await pumpEventQueue();

    expect(cubit.state, const ThemeState(darkMode: false));
    expect(
      (await SharedPreferences.getInstance()).getBool('isDarkMode'),
      isFalse,
    );

    await settings.darkMode.set(true);
    await pumpEventQueue();

    expect(cubit.state.darkMode, isTrue);
  });

  // A listener on the status must see every refusal, not only the first: a
  // repeated failure may not be an equal, dropped state.
  test('keeps the theme and says so, every time the phone refuses to store '
      'it', () async {
    final (PrefsStore store, _) = await openRefusingPrefs(
      legacyPrefs(),
      refused: <String>{'isDarkMode'},
    );
    final MemoryLogSink log = MemoryLogSink();
    final ThemeCubit cubit = ThemeCubit(
      settings: SettingsRepository(prefs: store),
      logger: memoryLogger(log),
    );
    addTearDown(cubit.close);
    final List<ThemeStatus> statuses = <ThemeStatus>[];
    cubit.stream.listen((ThemeState state) => statuses.add(state.status));

    await cubit.setDarkMode(false);
    await cubit.setDarkMode(false);
    await pumpEventQueue();

    expect(
      cubit.state,
      const ThemeState(darkMode: true, status: ThemeStatus.saveFailed),
    );
    expect(
      statuses.where((ThemeStatus s) => s == ThemeStatus.saveFailed),
      hasLength(2),
    );
    expect(log.lines.first, contains('Could not store the theme'));
  });
}
