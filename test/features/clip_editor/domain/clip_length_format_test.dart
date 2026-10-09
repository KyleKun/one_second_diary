// The length readout ("01.00") and the lengths read aloud.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length_format.dart';

void main() {
  test('the readout is zero-padded seconds and hundredths, rounds .990 s '
      'and up to the next second as v1.7 did, in the locale\'s decimals; '
      'read aloud, trailing zeros go, and an unknown locale is English', () {
    // (language, ms) -> readout
    final Map<(String, int), String> readouts = <(String, int), String>{
      ('en', 1000): '01.00',
      ('en', 1500): '01.50',
      ('en', 10500): '10.50',
      ('en', 640): '00.64',
      ('en', 990): '01.00',
      ('en', 2995): '03.00',
      ('en', 2989): '02.98',
      ('de', 1500): '01,50',
      ('pt', 1500): '01,50',
      ('zh', 1500): '01.50',
    };
    for (final MapEntry<(String, int), String> row in readouts.entries) {
      final (String language, int ms) = row.key;
      expect(
        ClipLengthFormat.of(language).readout(ms),
        row.value,
        reason: '${row.key}',
      );
    }

    // (language, ms) -> seconds read aloud
    final Map<(String, int), String> aloud = <(String, int), String>{
      ('en', 1000): '1',
      ('en', 1500): '1.5',
      ('en', 2345): '2.35',
      ('de', 1500): '1,5',
      ('xx', 1500): '1.5',
    };
    for (final MapEntry<(String, int), String> row in aloud.entries) {
      final (String language, int ms) = row.key;
      expect(
        ClipLengthFormat.of(language).seconds(ms),
        row.value,
        reason: '${row.key}',
      );
    }
  });
}
