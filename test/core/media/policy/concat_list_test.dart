import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/concat_list.dart';

void main() {
  // No trailing newline. Profile names (and user-made sub-folders) can
  // contain a quote; the concat demuxer reads '\'' as close quote, escaped
  // quote, reopen.
  test("one quoted file line per clip, CRLF between, ' escaped as '\\''", () {
    const String folder =
        '/storage/emulated/0/DCIM/OneSecondDiary/Profiles/My Trip';
    expect(
      ConcatList.content(<String>[
        '$folder/2024-01-01.mp4',
        '$folder/2024-01-02.mp4',
        '$folder/2024-01-03.mp4',
      ]),
      "file '$folder/2024-01-01.mp4'\r\n"
      "file '$folder/2024-01-02.mp4'\r\n"
      "file '$folder/2024-01-03.mp4'",
    );
    expect(
      ConcatList.content(<String>["/v/Profiles/Kid's/2024-01-01.mp4"]),
      r"file '/v/Profiles/Kid'\''s/2024-01-01.mp4'",
    );
  });

  // A movie with transitions gives every file its exact length, so a body whose subtitle
  // cue outlives its video still places the next file right after its last frame.
  test('with durations, a `duration <seconds>` line after each file; one '
      'per path or an ArgumentError', () {
    expect(
      ConcatList.content(
        <String>['/v/body-0.mp4', '/v/segment-0.mp4', '/v/2024-01-02.mp4'],
        durations: <String>['1.666667', '0.400000', '1.500000'],
      ),
      "file '/v/body-0.mp4'\r\nduration 1.666667\r\n"
      "file '/v/segment-0.mp4'\r\nduration 0.400000\r\n"
      "file '/v/2024-01-02.mp4'\r\nduration 1.500000",
    );
    expect(
      () => ConcatList.content(
        <String>['/v/a.mp4', '/v/b.mp4'],
        durations: <String>['1.000000'],
      ),
      throwsArgumentError,
    );
  });
}
