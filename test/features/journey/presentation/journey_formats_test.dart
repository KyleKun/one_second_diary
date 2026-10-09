// The Journey's formats: "Your life so far" has one unit under a minute
// (the page test checks the words). Display text never carries U+202F:
// `DisplayText.safe`, test/core/l10n.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/journey/presentation/journey_formats.dart';

void main() {
  test('under a minute a duration is one unit', () {
    expect(JourneyFormats.duration(45).secondary, isNull);
    expect(JourneyFormats.duration(914).secondary, isNotNull);
    expect(JourneyFormats.duration(8040).secondary, isNotNull);
  });
}
