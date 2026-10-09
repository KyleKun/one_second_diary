// The Diary's filter: any of the chosen tags, "Without tags", and a text
// search over a clip's tags, subtitle and place (case and accents folded
// like a tag). A clip not read yet matches a search through its tags only.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/diary/domain/clip_filter.dart';

void main() {
  const ClipMeta beach = ClipMeta(
    subtitleText: 'First swim of the Summer',
    locationText: 'Praia do Rosa',
  );

  test('an empty filter keeps every clip, read or not', () {
    const ClipFilter none = ClipFilter.none();
    expect(none.isEmpty, isTrue);
    expect(none.matches(tags: const <String>[], meta: null), isTrue);
    expect(none.matches(tags: const <String>['trip'], meta: beach), isTrue);
    expect(const ClipFilter(query: '   ').isEmpty, isTrue);
  });

  test('tags: any of the chosen ones, by fold; "Without tags" keeps the '
      'untagged only', () {
    final ClipFilter trips = ClipFilter(
      tags: TagFilter(anyOf: <String>{'Trip', 'kids'}),
    );
    expect(trips.matches(tags: const <String>['trip'], meta: null), isTrue);
    expect(trips.matches(tags: const <String>['bread'], meta: null), isFalse);
    expect(trips.matches(tags: const <String>[], meta: beach), isFalse);

    final ClipFilter untagged = ClipFilter(tags: TagFilter(untaggedOnly: true));
    expect(untagged.matches(tags: const <String>[], meta: null), isTrue);
    expect(untagged.matches(tags: const <String>['trip'], meta: null), isFalse);
  });

  test('a search finds a tag, the subtitle or the place, ignoring case and '
      'composing accents', () {
    expect(
      const ClipFilter(
        query: 'SUMMER',
      ).matches(tags: const <String>[], meta: beach),
      isTrue,
    );
    expect(
      const ClipFilter(
        query: 'rosa',
      ).matches(tags: const <String>[], meta: beach),
      isTrue,
    );
    expect(
      const ClipFilter(
        query: 'tri',
      ).matches(tags: const <String>['Trip'], meta: beach),
      isTrue,
    );
    expect(
      const ClipFilter(
        query: 'winter',
      ).matches(tags: const <String>['trip'], meta: beach),
      isFalse,
    );
    // "é" typed decomposed (e + combining acute) finds the composed one.
    expect(
      const ClipFilter(query: 'café').matches(
        tags: const <String>[],
        meta: const ClipMeta(subtitleText: 'Café da manhã'),
      ),
      isTrue,
    );
  });

  test('a clip not read yet matches a search through its tags only', () {
    const ClipFilter swim = ClipFilter(query: 'swim');
    expect(swim.matches(tags: const <String>['swim'], meta: null), isTrue);
    expect(swim.matches(tags: const <String>['trip'], meta: null), isFalse);
    expect(
      swim.matches(
        tags: const <String>['trip'],
        meta: const ClipMeta(durationMs: 1000),
      ),
      isFalse,
    );
  });

  test('tags and search both apply', () {
    final ClipFilter filter = ClipFilter(
      tags: TagFilter(anyOf: <String>{'trip'}),
      query: 'swim',
    );
    expect(filter.matches(tags: const <String>['trip'], meta: beach), isTrue);
    expect(filter.matches(tags: const <String>['kids'], meta: beach), isFalse);
    expect(filter.matches(tags: const <String>['trip'], meta: null), isFalse);
    expect(filter.matcher(tags: const <String>['trip'], meta: beach), isTrue);
  });
}
