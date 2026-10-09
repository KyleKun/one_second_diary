import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';

void main() {
  test('a tag is 1 to 30 characters of free text without a comma or a '
      'control character, new to the clip, on a clip with room for it', () {
    final List<String> nineteen = List<String>.generate(19, (int i) => 't$i');
    final Map<(String, List<String>), TagNameError?> cases =
        <(String, List<String>), TagNameError?>{
          ('trip', <String>[]): null,
          ('  sour   dough ', <String>['bread']): null,
          ('a' * 30, <String>[]): null,
          ('trip', nineteen): null,
          ('', <String>[]): TagNameError.empty,
          ('   ', <String>[]): TagNameError.empty,
          ('​', <String>[]): TagNameError.empty,
          ('a' * 31, <String>[]): TagNameError.tooLong,
          ('bread, trip', <String>[]): TagNameError.comma,
          ('sour\ndough', <String>[]): TagNameError.invalidCharacters,
          ('sour\u0000dough', <String>[]): TagNameError.invalidCharacters,
          ('Bread', <String>['trip', 'bread']): TagNameError.duplicate,
          ('José', <String>['José']): TagNameError.duplicate,
          ('trip', <String>[...nineteen, 't19']): TagNameError.tooMany,
        };
    for (final MapEntry<(String, List<String>), TagNameError?> entry
        in cases.entries) {
      final (String raw, List<String> existing) = entry.key;
      expect(
        TagName.validate(raw, existing: existing),
        entry.value,
        reason: '"$raw" with ${existing.length} existing',
      );
    }
  });

  test('a tag is stored trimmed, its whitespace collapsed, invisible '
      'characters removed and accents composed; two tags are the same '
      'whatever their casing or how their accents were typed', () {
    expect(TagName.clean('  sour \t  dough '), 'sour dough');
    expect(TagName.clean('tri​p‍'), 'trip');
    expect(TagName.clean('José'), 'José');
    expect(TagName.clean(' '), isEmpty);

    expect(TagName.fold(' Sour  DOUGH'), 'sour dough');
    expect(TagName.same('Bread', 'bread'), isTrue);
    expect(TagName.same('José', 'josé'), isTrue);
    expect(TagName.same('bread', 'breads'), isFalse);
  });

  test("a clip's tags are stored one per name, the casing typed first "
      'kept, sorted by name, invalid ones dropped, never more than 20', () {
    expect(
      TagName.normalize(<String>[
        'Trip',
        'bread',
        'trip',
        'BREAD',
        'sour  dough',
        '   ',
        'a,b',
        'x\ty', // a tab is a control character
        'line\nbreak',
        'a' * 31,
      ]),
      <String>['bread', 'sour dough', 'Trip'],
    );
    expect(TagName.normalize(const <String>[]), isEmpty);

    final List<String> many = List<String>.generate(25, (int i) => 'tag $i');
    final List<String> kept = TagName.normalize(<String>[...many, ...many]);
    expect(kept, hasLength(TagName.maxPerClip));
    expect(kept.toSet(), many.take(TagName.maxPerClip).toSet());
  });
}
