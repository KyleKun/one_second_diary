import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';

void main() {
  test('no filter keeps every clip; "any of" keeps the clips with one of '
      'the tags, whatever its casing; "none of" wins over "any of"', () {
    expect(TagFilter.none.isEmpty, isTrue);
    expect(TagFilter.none.matches(const <String>[]), isTrue);
    expect(TagFilter.none.matches(const <String>['bread']), isTrue);

    final TagFilter anyOf = TagFilter(anyOf: <String>{'Bread', 'kids'});
    expect(anyOf.isNotEmpty, isTrue);
    expect(anyOf.matches(const <String>['bread', 'trip']), isTrue);
    expect(anyOf.matches(const <String>['KIDS']), isTrue);
    expect(anyOf.matches(const <String>['trip']), isFalse);
    expect(anyOf.matches(const <String>[]), isFalse);

    final TagFilter noneOf = TagFilter(noneOf: <String>{'bread'});
    expect(noneOf.matches(const <String>[]), isTrue);
    expect(noneOf.matches(const <String>['trip']), isTrue);
    expect(noneOf.matches(const <String>['trip', 'Bread']), isFalse);

    // "Every trip clip except the bread ones."
    final TagFilter both = TagFilter(
      anyOf: <String>{'trip'},
      noneOf: <String>{'bread'},
    );
    expect(both.matches(const <String>['trip']), isTrue);
    expect(both.matches(const <String>['trip', 'bread']), isFalse);
    expect(both.matches(const <String>['kids']), isFalse);
  });

  test('"untagged" keeps only the clips without a tag', () {
    final TagFilter untagged = TagFilter(untaggedOnly: true);
    expect(untagged.isEmpty, isFalse);
    expect(untagged.matches(const <String>[]), isTrue);
    expect(untagged.matches(const <String>['trip']), isFalse);
    expect(untagged.withUntaggedOnly(untaggedOnly: false), TagFilter.none);
  });

  test('tapping a tag adds it to the filter, tapping it again (in any '
      'casing) removes it; two filters of the same tags are equal whatever '
      'the casing', () {
    final TagFilter one = TagFilter.none.toggleAny('Trip');
    expect(one.includes('trip'), isTrue);
    expect(one.anyOf, <String>{'Trip'});
    expect(one.toggleAny('TRIP'), TagFilter.none);

    final TagFilter left = one.toggleNone('Bread');
    expect(left.excludes('bread'), isTrue);
    expect(left.includes('trip'), isTrue);
    expect(left.toggleNone('bread'), one);

    expect(TagFilter(anyOf: <String>{'Bread'}), TagFilter(anyOf: {'bread'}));
    expect(
      TagFilter(anyOf: <String>{'bread'}),
      isNot(TagFilter(noneOf: <String>{'bread'})),
    );
    expect(
      TagFilter(anyOf: <String>{'bread'}),
      isNot(TagFilter(anyOf: <String>{'bread'}, untaggedOnly: true)),
    );
  });
}
