import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/profiles/domain/profile_name_error.dart';
import 'package:one_second_diary/features/profiles/domain/profile_name_validator.dart';

void main() {
  test('a display name may be in any language, with emoji, since it is no '
      'longer a folder name (flips G-8, SYNTHESIS Q-P3); it may not be '
      'empty (invisible format characters count as nothing), hold control '
      'characters, be "default" or the localised Default label, or repeat '
      'a name another profile shows (case, trimming, NFD accents and hidden '
      'characters do not disguise it)', () {
    for (final (
          String name,
          List<String> existing,
          String defaultLabel,
          ProfileNameError? error,
        )
        in <(String, List<String>, String, ProfileNameError?)>[
          for (final String name in <String>[
            'Bob',
            'José',
            'Família',
            'Straße',
            'Čeština',
            'Дача',
            'Прага',
            '旅行',
            'Kids 🎈',
            'Bob/Alice',
            'Bob_Trip-2024 2',
            // Emoji sequences joined by a zero-width joiner are visible.
            '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}',
            'Team \u{1F3F3}\uFE0F\u200D\u{1F308}',
          ])
            (name, const <String>[], 'Default', null),
          ('', const <String>[], 'Default', ProfileNameError.empty),
          ('   ', const <String>[], 'Default', ProfileNameError.empty),
          // Ideographic space.
          ('　', const <String>[], 'Default', ProfileNameError.empty),
          // Zero-width space, word joiner, zero-width joiners, BOM.
          ('​', const <String>[], 'Default', ProfileNameError.empty),
          ('⁠', const <String>[], 'Default', ProfileNameError.empty),
          ('‍‌', const <String>[], 'Default', ProfileNameError.empty),
          (' ﻿ ', const <String>[], 'Default', ProfileNameError.empty),
          // Rejected rather than trimmed away.
          (
            'Bob\t',
            const <String>[],
            'Default',
            ProfileNameError.invalidCharacters,
          ),
          (
            'Bob\nAlice',
            const <String>[],
            'Default',
            ProfileNameError.invalidCharacters,
          ),
          (
            'Bob ',
            const <String>[],
            'Default',
            ProfileNameError.invalidCharacters,
          ),
          ('DEFAULT', const <String>[], 'Default', ProfileNameError.reserved),
          (' default ', const <String>[], 'Default', ProfileNameError.reserved),
          ('Estandar', const <String>[], 'Estandar', ProfileNameError.reserved),
          (
            'ПО УМОЛЧАНИЮ',
            const <String>[],
            'По умолчанию',
            ProfileNameError.reserved,
          ),
          ('Default​', const <String>[], 'Default', ProfileNameError.reserved),
          ('De⁠fault', const <String>[], 'Default', ProfileNameError.reserved),
          ('bob', const <String>['Bob'], 'Default', ProfileNameError.duplicate),
          (
            '  Bob  ',
            const <String>['Bob'],
            'Default',
            ProfileNameError.duplicate,
          ),
          (
            'дача',
            const <String>['Travel', 'Дача'],
            'Default',
            ProfileNameError.duplicate,
          ),
          (
            'Bob​',
            const <String>['Bob'],
            'Default',
            ProfileNameError.duplicate,
          ),
          // A pasted NFD name is the precomposed one; the bare letter is not.
          (
            'José',
            const <String>['José'],
            'Default',
            ProfileNameError.duplicate,
          ),
          (
            'JOSÉ',
            const <String>['jose\u0301'],
            'Default',
            ProfileNameError.duplicate,
          ),
          (
            '\u010Ces\u030Cka',
            const <String>['Češka'],
            'Default',
            ProfileNameError.duplicate,
          ),
          ('Jose', const <String>['José'], 'Default', null),
          ('Bobby', const <String>['Bob'], 'Default', null),
        ]) {
      expect(
        ProfileNameValidator.validate(
          name,
          existingNames: existing,
          localizedDefaultLabel: defaultLabel,
        ),
        error,
        reason: '"$name" with $existing',
      );
    }
  });
}
