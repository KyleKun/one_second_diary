import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';

import 'localized_test_app.dart';

/// Shows what [read] returns, one [Text] per string, the way a widget reads
/// [Strings] during build.
class _TextsProbe extends StatelessWidget {
  const _TextsProbe(this.read);

  final List<String> Function() read;

  static Key keyAt(int index) => Key('probe.text.$index');

  @override
  Widget build(BuildContext context) {
    final List<String> texts = read();
    return Column(
      children: [
        for (int index = 0; index < texts.length; index++)
          Text(texts[index], key: keyAt(index)),
      ],
    );
  }
}

/// Serves [byLanguage] (language code -> translations) instead of the
/// asset files, for plural translations the app doesn't have.
class _InMemoryLoader extends AssetLoader {
  const _InMemoryLoader(this.byLanguage);

  final Map<String, Map<String, dynamic>> byLanguage;

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async =>
      byLanguage[locale.languageCode] ?? const <String, dynamic>{};
}

/// Renders [read] in [locale] from the real translation files, or from
/// [assetLoader] when given.
Future<List<String?>> _render(
  WidgetTester tester,
  Locale locale,
  List<String> Function() read, {
  AssetLoader assetLoader = const RootBundleAssetLoader(),
}) async {
  await tester.pumpWidget(
    LocalizedTestApp(
      // A new key per language mounts a fresh localisation root.
      key: ValueKey<Locale>(locale),
      startLocale: locale,
      assetLoader: assetLoader,
      child: _TextsProbe(read),
    ),
  );
  await tester.pumpAndSettle();
  final int count = find.byType(Text).evaluate().length;
  return [
    for (int index = 0; index < count; index++)
      tester.widget<Text>(find.byKey(_TextsProbe.keyAt(index))).data,
  ];
}

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableLevels = [];
  });

  // rootBundle caches each loaded file as a Future created in that test's
  // fake-async zone; a later test awaiting it would never resume.
  tearDown(rootBundle.clear);

  // For a key in en.json only, easy_localization would pick the English form
  // by the current language's CLDR category, which gives "1 clips" in zh,
  // "21 clip" in ru and "0 clip" in fr.
  testWidgets('English picks one or other, groups large counts and fills '
      'every placeholder; a plural the language lacks falls back to English '
      'with English plural rules', (tester) async {
    final Map<String, (List<String> Function(), List<String>)> rows = {
      'en': (
        () => [
          Strings.clipCount(1),
          Strings.clipCount(3),
          Strings.clipCount(1204, format: NumberFormat.decimalPattern('en')),
          Strings.makingMovieOfTotal(
            1204,
            done: 1000,
            format: NumberFormat.decimalPattern('en'),
          ),
          Strings.profileRowSubtitle(1, orientation: Strings.landscape),
        ],
        [
          '1 clip',
          '3 clips',
          '1,204 clips',
          '1,000 / 1,204 clips',
          'Landscape · 1 video',
        ],
      ),
      // zh has only "other" in CLDR.
      'zh': (
        () => [Strings.clipCount(1), Strings.clipCount(2)],
        ['1 clip', '2 clips'],
      ),
      // ru "one" also covers 21.
      'ru': (
        () => [
          Strings.clipCount(1),
          Strings.clipCount(21),
          Strings.clipCount(3),
        ],
        ['1 clip', '21 clips', '3 clips'],
      ),
      // fr "one" also covers 0.
      'fr': (
        () => [Strings.clipCount(0), Strings.clipCount(1)],
        ['0 clips', '1 clip'],
      ),
      // "Landschaft" is the de translation of the orientation.
      'de': (
        () => [
          Strings.profileRowSubtitle(914, orientation: Strings.landscape),
          Strings.diaryMonthProgress(28, recorded: 25),
        ],
        ['Landschaft · 914 videos', '25 of 28 days'],
      ),
    };

    for (final MapEntry(key: code, value: (read, expected)) in rows.entries) {
      expect(await _render(tester, Locale(code), read), expected, reason: code);
    }
  });

  // CLDR gives ru integers one / few / many; "other" is only for fractions,
  // so a complete Russian translation may leave it out.
  testWidgets('a translated plural uses the language\'s own forms, even '
      'without "other"', (tester) async {
    final List<String?> texts = await _render(
      tester,
      const Locale('ru'),
      () => [
        Strings.clipCount(1),
        Strings.clipCount(3),
        Strings.clipCount(5),
        Strings.clipCount(21),
      ],
      assetLoader: const _InMemoryLoader({
        'en': {
          'clipCount': {'one': '{count} clip', 'other': '{count} clips'},
        },
        'ru': {
          'clipCount': {
            'one': '{count} клип',
            'few': '{count} клипа',
            'many': '{count} клипов',
          },
        },
      }),
    );

    expect(texts, ['1 клип', '3 клипа', '5 клипов', '21 клип']);
  });
}
