// intl writes U+202F (NARROW NO-BREAK SPACE) in English times and French
// numbers of 1 000 and more, and Yusei Magic has no glyph for it.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:one_second_diary/core/l10n/display_text.dart';

void main() {
  setUpAll(initializeDateFormatting);

  test('a French 1 234 and an English 8 PM are drawn with a no-break space '
      'Yusei Magic has', () {
    final String french = NumberFormat.decimalPattern('fr').format(1234);
    final String time = DateFormat.jm('en').format(DateTime(2024, 1, 5, 20));
    expect(french, contains(' '));
    expect(time, contains(' '));

    expect(DisplayText.safe(french), '1 234');
    expect(DisplayText.safe(time), '8:00 PM');
  });
}
