import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/profiles/domain/profile_folder_keys.dart';

void main() {
  test('a folder key follows the legacy rule (flips G-8): trimmed; accents '
      'folded so the gallery album stays readable; anything outside the '
      'rule dropped and spaces collapsed, so "/" and "." never make a path; '
      'nothing left is the first free profile_<n>; a taken key gets the '
      'first free _<n>; never "default" in any case (Z MB-05)', () {
    for (final (String name, Set<String> taken, String key)
        in <(String, Set<String>, String)>[
          ('Travel', <String>{}, 'Travel'),
          ('  Bob_Trip-2024 2 ', <String>{}, 'Bob_Trip-2024 2'),
          ('José', <String>{}, 'Jose'),
          ('Família', <String>{}, 'Familia'),
          ('Straße', <String>{}, 'Strasse'),
          ('Čeština', <String>{}, 'Cestina'),
          ('Ærø Łódź', <String>{}, 'AEro Lodz'),
          ('Kids 🎈', <String>{}, 'Kids'),
          ('Bob/Alice', <String>{}, 'BobAlice'),
          ('a . b', <String>{}, 'a b'),
          ('Trip　　Rio', <String>{}, 'Trip Rio'),
          // A decomposed accent.
          ('école', <String>{}, 'ecole'),
          ('Дача', <String>{}, 'profile_1'),
          ('旅行', <String>{}, 'profile_1'),
          // Never a path segment.
          ('..', <String>{}, 'profile_1'),
          ('🎈', <String>{'profile_1', 'profile_2'}, 'profile_3'),
          ('Travel', <String>{'Travel'}, 'Travel_2'),
          ('Travel', <String>{'Travel', 'Travel_2'}, 'Travel_3'),
          // A profile labelled Default never takes Default's key.
          ('Défault', <String>{}, 'Default_2'),
          ('DEFAULT', <String>{}, 'DEFAULT_2'),
        ]) {
      expect(
        ProfileFolderKeys.forDisplayName(name, isTaken: taken.contains).value,
        key,
        reason: '"$name", taken $taken',
      );
    }
  });
}
