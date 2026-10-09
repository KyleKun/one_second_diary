import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/locale_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/locale_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/support.dart';
import '../../../../support/track_1c/refusing_shared_preferences.dart';

void main() {
  late String deviceLanguage;
  late MemoryLogSink log;

  setUp(() => deviceLanguage = 'en');

  LocaleCubit cubitOver(PrefsStore store) {
    log = MemoryLogSink();
    final LocaleCubit cubit = LocaleCubit(
      settings: SettingsRepository(prefs: store),
      deviceLanguageCode: () => deviceLanguage,
      logger: memoryLogger(log),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('never runs in a language the app has not got: it starts in the '
      'picked language, else a device language the app has (stored '
      'nowhere), else English', () async {
    for (final (String? stored, String device, AppLanguage language)
        in <(String?, String, AppLanguage)>[
          ('de', 'fr', AppLanguage.de),
          (null, 'pt', AppLanguage.pt),
          ('it', 'jv', AppLanguage.en),
        ]) {
      deviceLanguage = device;
      final LocaleCubit cubit = cubitOver(
        await openLegacyPrefs(
          legacyPrefs(extra: <String, Object>{'lang': ?stored}),
        ),
      );

      expect(cubit.state.language, language, reason: '$stored, $device');
      expect(cubit.state.status, LocaleStatus.ready);
      expect((await SharedPreferences.getInstance()).getString('lang'), stored);
    }
  });

  test('a pick is stored and switched to, with v1.7\'s log line; a pick the '
      'phone refuses keeps the language and says so every time, until one '
      'is stored', () async {
    final (PrefsStore store, RefusingSharedPreferences platform) =
        await openRefusingPrefs(legacyPrefs(), refused: <String>{'lang'});
    final LocaleCubit cubit = cubitOver(store);
    final List<LocaleStatus> statuses = <LocaleStatus>[];
    cubit.stream.listen((LocaleState state) => statuses.add(state.status));

    await cubit.pick(AppLanguage.ru);
    await cubit.pick(AppLanguage.ru);
    await pumpEventQueue();

    expect(
      cubit.state,
      const LocaleState(
        language: AppLanguage.en,
        status: LocaleStatus.saveFailed,
      ),
    );
    // The "couldn't save" snackbar listens to the status: every refusal
    // must reach it, not only the first.
    expect(
      statuses.where((LocaleStatus s) => s == LocaleStatus.saveFailed),
      hasLength(2),
    );
    expect(log.lines.first, contains('Could not store the language ru'));

    platform.refused.clear();
    log.lines.clear();
    await cubit.pick(AppLanguage.ru);

    expect(cubit.state, const LocaleState(language: AppLanguage.ru));
    expect((await SharedPreferences.getInstance()).getString('lang'), 'ru');
    expect(log.lines, <String>[
      '[INFO] 2024-01-05 10:00:00.000: [SETTINGS] App language changed to ru',
    ]);
  });

  test('a new device language is followed until the user picks one, and it '
      'clears a refused pick', () async {
    final (PrefsStore store, RefusingSharedPreferences platform) =
        await openRefusingPrefs(legacyPrefs(), refused: <String>{'lang'});
    final LocaleCubit cubit = cubitOver(store);
    await cubit.pick(AppLanguage.ru);

    deviceLanguage = 'cs';
    cubit.deviceLanguageChanged();

    expect(cubit.state, const LocaleState(language: AppLanguage.cs));
    expect(
      (await SharedPreferences.getInstance()).containsKey('lang'),
      isFalse,
    );

    platform.refused.clear();
    await cubit.pick(AppLanguage.fr);
    deviceLanguage = 'de';
    cubit.deviceLanguageChanged();

    expect(cubit.state.language, AppLanguage.fr);
  });
}
