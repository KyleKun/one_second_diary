import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

void main() {
  // The names are stored in orientation_<profile>.
  test("stores and parses v1.7's names; missing or unknown is landscape", () {
    expect(
      <String>[
        for (final VideoOrientation orientation in VideoOrientation.values)
          orientation.name,
      ],
      <String>['landscape', 'portrait'],
    );
    final Map<String?, VideoOrientation> cases = <String?, VideoOrientation>{
      'portrait': VideoOrientation.portrait,
      'landscape': VideoOrientation.landscape,
      null: VideoOrientation.landscape,
      '': VideoOrientation.landscape,
      'Portrait': VideoOrientation.landscape,
      'square': VideoOrientation.landscape,
    };
    for (final MapEntry<String?, VideoOrientation>(
          :String? key,
          :VideoOrientation value,
        )
        in cases.entries) {
      expect(VideoOrientation.parse(key), value, reason: '$key');
    }
  });
}
