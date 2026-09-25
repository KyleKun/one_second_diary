import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/utils/clip_trim_policy.dart';

void main() {
  group('resolveEndMilliseconds', () {
    test(
      'legacy mode pads a 1-second selection to the historical 1.5 seconds',
      () {
        expect(
          ClipTrimPolicy.resolveEndMilliseconds(
            selectedEndMilliseconds: 1000,
            videoDurationMilliseconds: 10000,
            strictClipLength: false,
          ),
          1500,
        );
      },
    );

    test('strict mode saves exactly the selected end point', () {
      expect(
        ClipTrimPolicy.resolveEndMilliseconds(
          selectedEndMilliseconds: 1000,
          videoDurationMilliseconds: 10000,
          strictClipLength: true,
        ),
        1000,
      );
    });

    test('legacy mode clamps the padded end to the video duration', () {
      expect(
        ClipTrimPolicy.resolveEndMilliseconds(
          selectedEndMilliseconds: 9800,
          videoDurationMilliseconds: 10000,
          strictClipLength: false,
        ),
        10000,
      );
    });

    test(
      'strict mode clamps to the video duration if selection overruns it',
      () {
        expect(
          ClipTrimPolicy.resolveEndMilliseconds(
            selectedEndMilliseconds: 10500,
            videoDurationMilliseconds: 10000,
            strictClipLength: true,
          ),
          10000,
        );
      },
    );

    test('legacy mode still pads longer selections, not just the minimum', () {
      // The padding has always been unconditional, not just a floor at
      // 1.5 seconds — a 3-second selection has always saved as 3.5 seconds.
      expect(
        ClipTrimPolicy.resolveEndMilliseconds(
          selectedEndMilliseconds: 3000,
          videoDurationMilliseconds: 10000,
          strictClipLength: false,
        ),
        3500,
      );
    });
  });
}
