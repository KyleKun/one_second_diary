// "Special thanks": the bundled CONTRIBUTORS.md.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/domain/credits.dart';

void main() {
  test('each "## " heading is a section of people, in file order: '
      'contributors link their GitHub profile, translators name a language '
      'the app ships or keep it as written', () {
    final List<CreditsSection> sections = Credits.parse('''
## Code Contributions
- Allen (@oiolong)

## Testing & Feedback
- Augusto Vesco

## Localization
- 丁禹懿 - Chinese
- Someone - Klingon
''');

    expect(sections, const <CreditsSection>[
      CreditsSection(
        title: 'Code Contributions',
        kind: CreditsKind.contributors,
        people: <CreditsPerson>[
          CreditsPerson(name: 'Allen', handle: 'oiolong'),
        ],
      ),
      CreditsSection(
        title: 'Testing & Feedback',
        kind: CreditsKind.other,
        people: <CreditsPerson>[CreditsPerson(name: 'Augusto Vesco')],
      ),
      CreditsSection(
        title: 'Localization',
        kind: CreditsKind.translators,
        people: <CreditsPerson>[
          CreditsPerson(name: '丁禹懿', language: AppLanguage.zh),
          CreditsPerson(name: 'Someone', note: 'Klingon'),
        ],
      ),
    ]);
    expect(
      sections.first.people.single.link,
      Uri.parse('https://github.com/oiolong'),
    );
    expect(sections[1].people.single.link, isNull);

    // The repository's own file: every contributor has a handle, every
    // translator a language the app ships.
    final List<CreditsSection> repository = Credits.parse(
      File('CONTRIBUTORS.md').readAsStringSync(),
    );
    final CreditsSection code = repository.firstWhere(
      (CreditsSection s) => s.kind == CreditsKind.contributors,
    );
    expect(code.people, isNotEmpty);
    expect(code.people.every((CreditsPerson p) => p.handle != null), isTrue);
    final CreditsSection translators = repository.firstWhere(
      (CreditsSection s) => s.kind == CreditsKind.translators,
    );
    expect(translators.people, isNotEmpty);
    expect(
      translators.people.where((CreditsPerson p) => p.language == null),
      isEmpty,
    );
  });
}
