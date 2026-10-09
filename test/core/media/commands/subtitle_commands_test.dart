import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/commands/subtitle_commands.dart';

import '../../../support/track_1a/platform_layouts.dart';

// The iOS SRT paths have a space ("Application Support"); each stays one
// element.
void main() {
  test('remux, remove and extract are the literal argv, every path whole on '
      'iOS', () {
    for (final Layout layout in <Layout>[android, ios]) {
      final String clip = '${layout.videos}2026-09-16.mp4';
      final String srt = '${layout.internal}/subtitles.srt';
      final String output = '${layout.cache}/scratch/job-7/2026-09-16.mp4';
      final String extracted = '${layout.internal}/temp.srt';
      for (final (String name, List<String> argv, List<String> expected)
          in <(String, List<String>, List<String>)>[
            // The clip is input 0, so its global tags (artist, album,
            // comment, location) are copied. The SRT replaces any subtitle
            // stream.
            (
              'remux',
              SubtitleCommands.remux(
                clip: clip,
                subtitles: srt,
                output: output,
              ),
              <String>[
                '-i', clip, '-i', srt, //
                '-c:s', 'mov_text', '-c:v', 'copy', '-c:a', 'copy', //
                '-map', '0:v', '-map', '0:a?', '-map', '1', //
                '-disposition:s:0', 'default', output, '-y',
              ],
            ),
            // Stream copy, tags kept.
            (
              'remove',
              SubtitleCommands.remove(clip: clip, output: output),
              <String>[
                '-i', clip, '-c:v', 'copy', '-c:a', 'copy', //
                '-map', '0:v', '-map', '0:a?', '-sn', output, '-y',
              ],
            ),
            // The .srt output makes ffmpeg pick only the subtitle stream; a
            // clip without one fails, which reads as "no subtitles".
            (
              'extract',
              SubtitleCommands.extract(clip: clip, output: extracted),
              <String>['-i', clip, extracted, '-y'],
            ),
          ]) {
        expect(argv, expected, reason: '${layout.name} $name');
      }
    }
  });
}
