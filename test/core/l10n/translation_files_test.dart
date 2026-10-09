import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/osd_localization.dart';

import 'plural_forms.dart';

Map<String, dynamic> _readTranslations(String code) {
  final File file = File('${OsdLocalization.path}/$code.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

List<String> get _supportedCodes => [
  for (final locale in OsdLocalization.supportedLocales) locale.languageCode,
];

void main() {
  test('the translations folder holds one JSON file per supported locale', () {
    final List<String> files =
        Directory(OsdLocalization.path)
            .listSync()
            .whereType<File>()
            .map((file) => file.uri.pathSegments.last)
            .where((name) => !name.startsWith('.'))
            .toList()
          ..sort();

    expect(files, [for (final code in _supportedCodes..sort()) '$code.json']);
  });

  // easy_localization picks a form by CLDR category, not by exact number:
  // ru "one" also serves 21 and 31, and zh/id have only "other". So every
  // form must show the number, and exact-number copy ("Delete this movie?",
  // "No clips found") needs a key of its own.
  test('en.json plurals have the one and other forms English picks, name '
      'only CLDR categories and show the {count} in every form', () {
    for (final MapEntry<String, dynamic> plural in _readTranslations(
      'en',
    ).entries) {
      if (plural.value is! Map<String, dynamic>) continue;
      final Map<String, dynamic> forms = plural.value as Map<String, dynamic>;
      expect(
        forms.keys,
        containsAll(<String>['one', 'other']),
        reason: plural.key,
      );
      expect(
        _pluralCategories.containsAll(forms.keys),
        isTrue,
        reason: '${plural.key}: ${forms.keys}',
      );
      for (final MapEntry<String, dynamic> form in forms.entries) {
        expect(
          form.value,
          contains('{count}'),
          reason: '${plural.key}.${form.key}',
        );
      }
    }
  });

  // A plain string where English has plural forms (or the reverse) would
  // make Strings read it the wrong way: plural() on a string throws and tr()
  // on a plural map shows the raw key.
  test('every translation is a JSON object of strings or plural maps, with '
      'no key en.json lacks, each shaped like its English', () {
    final Map<String, dynamic> english = _readTranslations('en');
    for (final String code in _supportedCodes) {
      final Map<String, dynamic> translations = _readTranslations(code);

      expect(translations, isNotEmpty, reason: code);
      expect(
        translations.keys.toSet().difference(english.keys.toSet()),
        isEmpty,
        reason: code,
      );
      for (final MapEntry<String, dynamic> entry in translations.entries) {
        expect(
          entry.value,
          anyOf(isA<String>(), isA<Map<String, dynamic>>()),
          reason: '$code.${entry.key}',
        );
        expect(
          entry.value is Map,
          english[entry.key] is Map,
          reason: '$code.${entry.key} is ${entry.value.runtimeType}',
        );
      }
    }
  });

  // A translated plural shaped like English ({one, other}) passes every
  // other check but says "3 клипов" instead of "3 клипа" in Russian.
  test('every translated plural has every form its language needs', () {
    for (final String code in _supportedCodes) {
      expect(requiredPluralForms, contains(code));
      for (final MapEntry<String, dynamic> entry in _readTranslations(
        code,
      ).entries) {
        if (entry.value is! Map<String, dynamic>) continue;
        final Map<String, dynamic> forms = entry.value as Map<String, dynamic>;
        expect(
          forms.keys,
          containsAll(requiredPluralForms[code]!),
          reason: '$code.${entry.key}',
        );
      }
    }
  });

  test('every translation uses the same {placeholders} as en.json', () {
    final Map<String, dynamic> english = _readTranslations('en');
    for (final String code in _supportedCodes) {
      final Map<String, dynamic> translations = _readTranslations(code);
      for (final String key in translations.keys) {
        expect(
          _placeholders(translations[key]),
          _placeholders(english[key]),
          reason: '$code.$key',
        );
      }
    }
  });
}

const Set<String> _pluralCategories = {
  'zero',
  'one',
  'two',
  'few',
  'many',
  'other',
};

final RegExp _placeholder = RegExp(r'\{(\w*)\}');

/// The `{name}` placeholders in a string value, or in every form of a plural
/// map. A positional `{}` counts as the empty name.
Set<String> _placeholders(Object? value) => switch (value) {
  final String text => {
    for (final match in _placeholder.allMatches(text)) match.group(1)!,
  },
  final Map<String, dynamic> forms => {
    for (final form in forms.values) ..._placeholders(form),
  },
  _ => const {},
};
