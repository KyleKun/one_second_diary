import 'package:flutter_test/flutter_test.dart';

import '../../../tool/l10n/untranslated_report.dart';

void main() {
  const Map<String, dynamic> english = {
    'language': 'Language',
    'journey': 'Journey',
    'clipCount': {'one': '{count} clip', 'other': '{count} clips'},
  };

  test('lists the English keys each other language lacks, and prints one '
      'line per language, a plural key counted once', () {
    final Map<String, List<String>> untranslated = untranslatedKeys(
      english: english,
      byLanguage: {
        'en': english,
        'de': {'language': 'Sprache'},
        'ru': {
          'language': 'Язык',
          'journey': 'Путь',
          'clipCount': {'one': '{count} клип', 'few': '{count} клипа'},
        },
      },
    );

    expect(untranslated, {
      'de': ['journey', 'clipCount'],
      'ru': <String>[],
    });

    final String report = formatUntranslatedReport(
      untranslated: untranslated,
      total: english.length,
    );

    expect(
      report,
      'Untranslated keys per language (of 3 in en.json; the app shows '
      'English for them):\n'
      '  de: 2\n'
      '  ru: 0\n',
    );
  });
}
