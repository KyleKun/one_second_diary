import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/commands/probe_commands.dart';

// The iOS path (with a space) stays one element.
const List<String> paths = <String>[
  '/storage/emulated/0/DCIM/OneSecondDiary/2026-09-28.mp4',
  '/var/mobile/Containers/Data/Application/X/Documents/OneSecondDiary/'
      'Profiles/My Trip/2026-09-28.mp4',
];

void main() {
  // The JSON probe has `-show_chapters` after `-show_streams`, so a movie's chapters come
  // back with its tags after a reinstall. A clip has none.
  test('the audio probe (prints "audio" only when a first audio stream '
      "exists) is v1.7's argv; the full JSON probe is v1.7's plus "
      '-show_chapters (D25)', () {
    for (final String clip in paths) {
      expect(ProbeCommands.audioStream(clip), <String>[
        '-v', 'quiet', '-select_streams', 'a:0', //
        '-show_entries', 'stream=codec_type', '-of', 'default=nw=1:nk=1', clip,
      ], reason: clip);
      expect(ProbeCommands.streams(clip), <String>[
        '-v', 'quiet', '-print_format', 'json', //
        '-show_format', '-show_streams', '-show_chapters', clip,
      ], reason: clip);
    }
  });

  // The keyframe probe lists the first video stream's packets (time and flags) without
  // decoding a frame.
  test('the keyframe probe: one CSV line per video packet', () {
    for (final String clip in paths) {
      expect(ProbeCommands.keyframes(clip), <String>[
        '-v', 'quiet', '-select_streams', 'v:0', //
        '-show_entries', 'packet=pts_time,flags', '-of', 'csv=p=0', clip,
      ], reason: clip);
    }
  });
}
