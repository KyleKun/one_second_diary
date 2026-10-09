// TagsDraft: what the tags sheet lets the user add and remove, why a tag
// is refused, and when Save has something to write.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/features/clips/domain/tags_draft.dart';

void main() {
  group('add', () {
    test('adds a tag as typed, cleaned, after the ones it has; Save then has '
        'something to write', () {
      final (TagsDraft draft, TagNameError? error) = TagsDraft.of(<String>[
        'trip',
      ]).add('  Sour   dough ');

      expect(error, isNull);
      expect(draft.tags, <String>['trip', 'Sour dough']);
      expect(draft.isDirty, isTrue);
      expect(draft.normalized, <String>['Sour dough', 'trip']);
    });

    test('refuses an empty tag, a comma, a control character, a tag too '
        'long, a duplicate in another casing and a 21st tag, leaving the '
        'draft as it was', () {
      final TagsDraft one = TagsDraft.of(<String>['Trip']);
      TagNameError? errorOf(TagsDraft draft, String raw) {
        final (TagsDraft next, TagNameError? error) = draft.add(raw);
        expect(next, same(draft));
        return error;
      }

      expect(errorOf(one, '   '), TagNameError.empty);
      expect(errorOf(one, 'a,b'), TagNameError.comma);
      expect(errorOf(one, 'a\nb'), TagNameError.invalidCharacters);
      expect(errorOf(one, 'x' * (TagName.maxLength + 1)), TagNameError.tooLong);
      expect(errorOf(one, 'trip'), TagNameError.duplicate);

      final TagsDraft full = TagsDraft.of(<String>[
        for (int i = 0; i < TagName.maxPerClip; i++) 'tag $i',
      ]);
      expect(errorOf(full, 'one more'), TagNameError.tooMany);
    });
  });

  group('remove', () {
    test('drops the tag whatever its casing, and leaves a draft without it '
        'alone', () {
      final TagsDraft draft = TagsDraft.of(<String>['Trip', 'kids']);

      final TagsDraft without = draft.remove('TRIP');
      expect(without.tags, <String>['kids']);
      expect(without.isDirty, isTrue);
      expect(without.remove('bread'), same(without));
    });

    test('removing every tag is a change: Save writes an empty list', () {
      final TagsDraft draft = TagsDraft.of(<String>['trip']).remove('trip');

      expect(draft.isEmpty, isTrue);
      expect(draft.isDirty, isTrue);
      expect(draft.normalized, isEmpty);
    });
  });

  group('isDirty', () {
    test('is false as opened, and after a tag is removed and added back in '
        'another casing (the same tag)', () {
      final TagsDraft draft = TagsDraft.of(<String>['trip', 'kids']);
      expect(draft.isDirty, isFalse);

      final (TagsDraft back, _) = draft.remove('kids').add('KIDS');
      expect(back.isDirty, isFalse);
    });
  });
}
