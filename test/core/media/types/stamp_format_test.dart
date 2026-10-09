import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';

void main() {
  test('ids match the dateFormatId preference; anything but 1 is numeric', () {
    expect(StampFormat.numeric.id, 0);
    expect(StampFormat.written.id, 1);
    final Map<int, StampFormat> cases = <int, StampFormat>{
      0: StampFormat.numeric,
      1: StampFormat.written,
      2: StampFormat.numeric,
      -1: StampFormat.numeric,
    };
    for (final MapEntry<int, StampFormat>(:int key, :StampFormat value)
        in cases.entries) {
      expect(StampFormat.fromId(key), value, reason: '$key');
    }
  });
}
