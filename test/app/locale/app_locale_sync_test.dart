import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:one_second_diary/app/locale/app_locale_sync.dart';
import 'package:one_second_diary/app/osd_localization_root.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/locale_cubit.dart';

import '../../support/support.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableLevels = [];
  });

  tearDown(rootBundle.clear);
  tearDown(() => Intl.defaultLocale = null);

  Future<LocaleCubit> pump(
    WidgetTester tester, {
    required String Function() deviceLanguage,
  }) async {
    final LocaleCubit cubit = LocaleCubit(
      settings: SettingsRepository(prefs: await openLegacyPrefs(legacyPrefs())),
      deviceLanguageCode: deviceLanguage,
      logger: memoryLogger(MemoryLogSink()),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider<LocaleCubit>.value(
        value: cubit,
        child: OsdLocalizationRoot(
          language: cubit.state.language,
          child: AppLocaleSync(
            child: Builder(
              builder: (BuildContext context) => MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                home: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  Locale appLocale(WidgetTester tester) =>
      tester.element(find.byType(MaterialApp)).locale;

  testWidgets('a picked language becomes the app locale', (
    WidgetTester tester,
  ) async {
    final LocaleCubit cubit = await pump(tester, deviceLanguage: () => 'en');

    await cubit.pick(AppLanguage.fr);
    await tester.pumpAndSettle();

    expect(appLocale(tester), const Locale('fr'));
    expect(Strings.language, 'Langue');
  });

  testWidgets('intl follows the app language', (WidgetTester tester) async {
    await tester.runAsync(initializeDateFormatting);
    final LocaleCubit cubit = await pump(tester, deviceLanguage: () => 'en');

    await cubit.pick(AppLanguage.de);
    await tester.pumpAndSettle();
    expect(Intl.getCurrentLocale(), 'de');
    expect(DateFormat.yMMMM().format(DateTime(2026, 9)), 'September 2026');

    await cubit.pick(AppLanguage.fr);
    await tester.pumpAndSettle();
    expect(Intl.getCurrentLocale(), 'fr');
    expect(DateFormat.yMMMM().format(DateTime(2026, 9)), 'septembre 2026');
  });

  testWidgets('the app follows a new device language while none is '
      'picked', (WidgetTester tester) async {
    String device = 'en';
    await pump(tester, deviceLanguage: () => device);

    device = 'pt';
    tester.platformDispatcher.localesTestValue = const <Locale>[
      Locale('pt', 'BR'),
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpAndSettle();

    expect(appLocale(tester), const Locale('pt'));
  });
}
