import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/osd_localization.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/domain/locale_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'localized_test_app.dart';
import 'plural_forms.dart';

/// Shows a few [Strings] the way a widget reads them.
class _StringsProbe extends StatelessWidget {
  const _StringsProbe();

  static const Key languageKey = Key('probe.language');
  static const Key persistentKey = Key('probe.usePersistentNotifications');
  static const Key mailBodyKey = Key('probe.errorMailBody');
  static const Key defaultProfileKey = Key('probe.defaultProfile');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(Strings.language, key: languageKey),
        Text(Strings.usePersistentNotifications, key: persistentKey),
        Text(Strings.errorMailBody, key: mailBodyKey),
        Text(Strings.defaultProfile, key: defaultProfileKey),
      ],
    );
  }
}

String? _textOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data;

Future<void> _pumpLocalized(
  WidgetTester tester, {
  required Locale startLocale,
  Widget child = const _StringsProbe(),
  AssetLoader assetLoader = const RootBundleAssetLoader(),
}) async {
  await tester.pumpWidget(
    LocalizedTestApp(
      // A new key per language mounts a fresh localisation root.
      key: ValueKey<Locale>(startLocale),
      startLocale: startLocale,
      assetLoader: assetLoader,
      child: child,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableLevels = [];
  });

  // rootBundle caches each loaded file as a Future created in that test's
  // fake-async zone; a later test awaiting it would never resume.
  tearDown(rootBundle.clear);

  group('per-key English fallback', () {
    testWidgets('keys missing from zh.json show English, the rest Chinese', (
      tester,
    ) async {
      await _pumpLocalized(tester, startLocale: const Locale('zh'));

      expect(_textOf(tester, _StringsProbe.languageKey), '语言');
      expect(
        _textOf(tester, _StringsProbe.persistentKey),
        'Persistent notification',
      );
      expect(
        _textOf(tester, _StringsProbe.mailBodyKey),
        'Tell me what happened and what you expected:',
      );
    });
  });

  group('runtime language change', () {
    // Strings reads no BuildContext, so a widget shows the new language only
    // once the app rebuilds it; this checks what a rebuild would read.
    testWidgets('switches Strings and stores no easy_localization pref '
        '(the app owns "lang", decision D5)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpLocalized(tester, startLocale: const Locale('en'));

      unawaited(
        tester
            .element(find.byKey(_StringsProbe.languageKey))
            .setLocale(const Locale('de')),
      );
      await tester.pumpAndSettle();

      expect(Strings.language, 'Sprache');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });
  });

  group('device locale resolution', () {
    // The app's one resolution path: LocaleResolver picks an AppLanguage,
    // and OsdLocalization turns it into the locale easy_localization loads.
    Locale appLocaleOnDevice(Locale device) => OsdLocalization.localeOf(
      LocaleResolver.resolve(
        storedLang: '',
        deviceLanguageCode: device.languageCode,
      ),
    );

    test('the supported locales are the app languages, English first, so an '
        'unsupported device language lands on English, not Belarusian (the '
        'gen-l10n trap, G_settings.md §7.7)', () {
      expect(OsdLocalization.supportedLocales.first, const Locale('en'));
      expect(OsdLocalization.fallbackLocale, const Locale('en'));
      expect(
        OsdLocalization.supportedLocales,
        unorderedEquals(<Locale>[
          for (final AppLanguage language in AppLanguage.values)
            Locale(language.code),
        ]),
      );
      expect(appLocaleOnDevice(const Locale('it', 'IT')), const Locale('en'));
      expect(
        basicLocaleListResolution(const [
          Locale('it', 'IT'),
        ], OsdLocalization.supportedLocales),
        const Locale('en'),
      );
    });

    testWidgets('a pt_BR device shows Portuguese, Material labels too', (
      tester,
    ) async {
      await _pumpLocalized(
        tester,
        startLocale: appLocaleOnDevice(const Locale('pt', 'BR')),
      );

      expect(_textOf(tester, _StringsProbe.languageKey), 'Idioma');
      expect(_textOf(tester, _StringsProbe.defaultProfileKey), 'Padrão');
      expect(
        Localizations.localeOf(
          tester.element(find.byKey(_StringsProbe.languageKey)),
        ),
        const Locale('pt'),
      );
      final BuildContext context = tester.element(
        find.byKey(_StringsProbe.languageKey),
      );
      expect(MaterialLocalizations.of(context).cancelButtonLabel, 'Cancelar');
    });
  });

  group('plural categories', () {
    Future<Map<num, String?>> pluralsIn(
      WidgetTester tester,
      Locale locale,
    ) async {
      await _pumpLocalized(
        tester,
        startLocale: locale,
        assetLoader: const _PluralFormsLoader(),
        child: const _PluralProbe(),
      );
      return {
        for (final num count in _PluralProbe.counts)
          count: _textOf(tester, _PluralProbe.keyFor(count)),
      };
    }

    testWidgets('whole numbers pick the CLDR form of each language, and '
        'exactly the forms requiredPluralForms lists', (tester) async {
      // ru "one" also covers 21; cs has no "many" for whole numbers; en 0
      // uses "other", never "zero".
      const Map<String, Map<num, String>> samples = {
        'ru': {
          0: 'many 0',
          1: 'one 1',
          3: 'few 3',
          5: 'many 5',
          11: 'many 11',
          21: 'one 21',
          22: 'few 22',
        },
        'cs': {
          0: 'other 0',
          1: 'one 1',
          3: 'few 3',
          5: 'other 5',
          11: 'other 11',
          21: 'other 21',
          22: 'other 22',
        },
        'en': {
          0: 'other 0',
          1: 'one 1',
          3: 'other 3',
          5: 'other 5',
          11: 'other 11',
          21: 'other 21',
          22: 'other 22',
        },
      };
      for (final MapEntry(key: code, value: expected) in samples.entries) {
        expect(await pluralsIn(tester, Locale(code)), expected, reason: code);
      }

      // requiredPluralForms is what translation_files_test.dart asks a
      // translated plural for: every category a whole number can pick, plus
      // "other".
      for (final MapEntry(key: code, value: forms)
          in requiredPluralForms.entries) {
        await pluralsIn(tester, Locale(code));
        final Set<String> picked = {
          for (int count = 0; count < 1000; count++)
            'clips'.plural(count).split(' ').first,
        };
        expect({...picked, 'other'}, forms, reason: code);
      }
    });
  });
}

/// Serves one plural key whose every form names its own CLDR category, for
/// any language.
class _PluralFormsLoader extends AssetLoader {
  const _PluralFormsLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async => {
    'clips': {
      'zero': 'zero {}',
      'one': 'one {}',
      'two': 'two {}',
      'few': 'few {}',
      'many': 'many {}',
      'other': 'other {}',
    },
  };
}

/// Shows the `clips` plural for each of [counts].
class _PluralProbe extends StatelessWidget {
  const _PluralProbe();

  /// Whole numbers only: easy_localization rounds fractions (1.5 plurals
  /// like 2).
  static const List<num> counts = [0, 1, 3, 5, 11, 21, 22];

  static Key keyFor(num count) => Key('probe.plural.$count');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final num count in counts)
          Text('clips'.plural(count), key: keyFor(count)),
      ],
    );
  }
}
