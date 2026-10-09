import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/commands/keywords_commands.dart';

void main() {
  test("setting a clip's tags is a stream copy of its video, audio and "
      'subtitles with the keywords tag set or deleted, the other tags '
      'copied by default, the path its own element', () {
    const String clip = '/Application Support/OneSecondDiary/2024-01-05.mp4';
    const String output = '/scratch/out 1/2024-01-05.mp4';
    const List<String> common = <String>[
      '-i',
      clip,
      '-c',
      'copy',
      '-map',
      '0:v',
      '-map',
      '0:a?',
      '-map',
      '0:s?',
      '-metadata',
    ];

    expect(
      KeywordsCommands.set(
        clip: clip,
        output: output,
        tags: <String>['bread', 'sour dough', 'trip'],
      ),
      <String>[...common, 'keywords=bread,sour dough,trip', output, '-y'],
    );
    expect(
      KeywordsCommands.set(clip: clip, output: output, tags: const <String>[]),
      <String>[...common, 'keywords=', output, '-y'],
    );
  });
}
