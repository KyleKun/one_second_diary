// Prints how many en.json keys each language has no translation for (new
// strings ship in English first, and CI reports the untranslated keys but
// never fails on them). Run from the repository root:
//
//   dart run tool/l10n/untranslated_report.dart
//
// Pure Dart, so it runs on the plain Dart VM.

import 'dart:convert';
import 'dart:io';

/// The folder that holds `<code>.json` per language (`OsdLocalization.path`).
const String translationsPath = 'assets/translations';

/// For every language in [byLanguage] but English, the [english] keys it has
/// no translation for, in en.json order.
///
/// A plural key is one key: it counts as translated when the language has it
/// with any of its forms, as `Strings` reads it.
Map<String, List<String>> untranslatedKeys({
  required Map<String, dynamic> english,
  required Map<String, Map<String, dynamic>> byLanguage,
}) => {
  for (final MapEntry<String, Map<String, dynamic>> language
      in byLanguage.entries)
    if (language.key != 'en')
      language.key: [
        for (final String key in english.keys)
          if (!language.value.containsKey(key)) key,
      ],
};

/// The report CI prints: one line per language, sorted by code, with the
/// number of untranslated keys out of [total].
String formatUntranslatedReport({
  required Map<String, List<String>> untranslated,
  required int total,
}) {
  final StringBuffer report = StringBuffer(
    'Untranslated keys per language (of $total in en.json; the app shows '
    'English for them):\n',
  );
  for (final String code in untranslated.keys.toList()..sort()) {
    report.writeln('  $code: ${untranslated[code]!.length}');
  }
  return report.toString();
}

Map<String, dynamic> _read(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

void main() {
  final Map<String, Map<String, dynamic>> byLanguage = {
    for (final File file in Directory(
      translationsPath,
    ).listSync().whereType<File>())
      if (file.uri.pathSegments.last case final String name
          when name.endsWith('.json') && !name.startsWith('.'))
        name.substring(0, name.length - '.json'.length): _read(file),
  };
  final Map<String, dynamic> english = byLanguage['en']!;
  stdout.write(
    formatUntranslatedReport(
      untranslated: untranslatedKeys(english: english, byLanguage: byLanguage),
      total: english.length,
    ),
  );
}
