import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/keywords_tag.dart';

void main() {
  // The tag travels with the file: what is written must read back as the
  // same tags, in the same order, whatever the script.
  test("a clip's tags are one comma-separated keywords value that reads "
      'back in order, Unicode kept; no tags is no tag at all', () {
    const List<String> tags = <String>['bread', 'sour dough', 'trip'];
    expect(KeywordsTag.format(tags), 'bread,sour dough,trip');
    expect(KeywordsTag.parse('bread,sour dough,trip'), tags);

    for (final List<String> unicode in <List<String>>[
      <String>['雨', 'São Paulo', 'café ☕'],
      <String>['Ünïcödé'],
      <String>["Val d'Isère", 'a "quoted" tag'],
    ]) {
      expect(KeywordsTag.parse(KeywordsTag.format(unicode)), unicode);
    }

    expect(KeywordsTag.format(const <String>[]), '');
    expect(KeywordsTag.parse(null), isEmpty);
    expect(KeywordsTag.parse(''), isEmpty);
  });

  test('a tag can never hold the separator', () {
    expect(
      () => KeywordsTag.format(<String>['bread', 'a,b']),
      throwsArgumentError,
    );
  });

  // A keywords tag written by another app, or by hand, is still read:
  // parts are trimmed, empty parts and exact repeats dropped, and the
  // casing and order are the file's.
  test('reading a tag written by hand: trimmed, empties and exact repeats '
      'dropped, order and casing kept', () {
    expect(KeywordsTag.parse(' bread , ,trip,bread,Bread,,'), <String>[
      'bread',
      'trip',
      'Bread',
    ]);
    expect(KeywordsTag.parse(' , ,'), isEmpty);
  });
}
