import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/stamp_text_files.dart';

void main() {
  // No place is an empty file. A trailing newline in date.txt would draw an
  // empty second line and lift the bottom-anchored written date.
  test('location.txt ends with a CR; date.txt is the stamp text exactly', () {
    expect(StampTextFiles.location('Tokyo, Japan'), 'Tokyo, Japan\r');
    expect(StampTextFiles.location('a\nb'), 'a\nb\r');
    expect(StampTextFiles.location(''), '');
    expect(StampTextFiles.location(null), '');
    for (final String date in <String>[
      '6 февраля 2024 г.',
      '02/06/2024',
      '2024年2月6日',
      '',
    ]) {
      expect(StampTextFiles.date(date), date);
    }
  });
}
