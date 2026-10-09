import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/clip_trim_policy.dart';

void main() {
  // No end pad: a clip ends exactly where the trim ends, floored to the ms and never past
  // the source. Each row: (duration, selected end, saved end).
  test('the saved end is the selected end, floored, never past the source: '
      'no pad, whatever the old strict switch said', () {
    const List<(int, double, int)> sweep = <(int, double, int)>[
      (0, 0, 0),
      (0, 0.99, 0),
      (0, 9600, 0),
      (900, 0.99, 0),
      (900, 499.5, 499),
      (900, 1000, 900),
      (1000, 999.9, 999),
      (1000, 1000, 1000),
      (1000, 1499.99, 1000),
      (1500, 1499.99, 1499),
      (1500, 1500, 1500),
      (2999, 1000, 1000),
      (2999, 9600, 2999),
      (10000, 9600, 9600),
      (60000, 59999.5, 59999),
      (60000, 60000, 60000),
    ];
    for (final (int duration, double end, int saved) in sweep) {
      expect(
        ClipTrimPolicy.resolveEndMilliseconds(
          selectedEndMilliseconds: end,
          videoDurationMilliseconds: duration,
        ),
        saved,
        reason: 'end $end, duration $duration',
      );
    }
  });
}
