import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/commands/concat_command.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';

import '../../../support/track_1a/platform_layouts.dart';

void main() {
  // The concat demuxer, a stream copy of every stream at 30 fps. The list path stays one
  // element on iOS, where it has a space ("Application Support").
  //
  // The title, `profile=<key>` comment and the clips and days in `description` are written
  // in the same pass, in that order; a tag without a value is left out.
  //
  // With a chapters file the concat gains ONE input (`-i <chapters>`, right after the list)
  // and `-map_chapters 1` right after `-map 0`; nothing else moves. Without one the argv
  // is the plain concat.
  test('every concat is the literal argv: v1.7 on Android, every path whole '
      'on iOS, the movie tags on the same copy', () {
    final List<(String, List<String>, List<String>)> cases =
        <(String, List<String>, List<String>)>[];
    for (final Layout layout in <Layout>[android, ios]) {
      final String list = '${layout.internal}/videos.txt';
      final String movie = '${layout.videos}Movies/OSD-Movie-3-2026-09-28.mp4';
      const List<String> head = <String>['-f', 'concat', '-safe', '0', '-i'];
      const List<String> copy = <String>['-r', '30', '-map', '0', '-c', 'copy'];
      cases.addAll(<(String, List<String>, List<String>)>[
        (
          '${layout.name}: no tags (v1.7)',
          ConcatCommand.build(listPath: list, outputPath: movie),
          <String>[...head, list, ...copy, movie, '-y'],
        ),
        (
          '${layout.name}: title, comment and description',
          ConcatCommand.build(
            listPath: list,
            outputPath: movie,
            title: 'September 2026',
            comment: 'profile=Work',
            description: 'clips=25;from=2026-09-01;to=2026-09-28',
          ),
          <String>[
            ...head, list, ...copy, //
            '-metadata', 'title=September 2026',
            '-metadata', 'comment=profile=Work',
            '-metadata', 'description=clips=25;from=2026-09-01;to=2026-09-28',
            movie, '-y',
          ],
        ),
        (
          '${layout.name}: title and comment, no description',
          ConcatCommand.build(
            listPath: list,
            outputPath: movie,
            title: 'September 2026',
            comment: 'profile=Work',
          ),
          <String>[
            ...head, list, ...copy, //
            '-metadata', 'title=September 2026',
            '-metadata', 'comment=profile=Work',
            movie, '-y',
          ],
        ),
        (
          '${layout.name}: no title, the Default comment',
          ConcatCommand.build(
            listPath: list,
            outputPath: movie,
            title: null,
            comment: 'profile=',
          ),
          <String>[
            ...head, list, ...copy, //
            '-metadata', 'comment=profile=', movie, '-y',
          ],
        ),
        (
          '${layout.name}: chapters (D25): one more input and -map_chapters 1',
          ConcatCommand.build(
            listPath: list,
            outputPath: movie,
            title: 'September 2026',
            comment: 'profile=Work',
            description: 'clips=25;from=2026-09-01;to=2026-09-28',
            chaptersPath: '${layout.internal}/chapters.txt',
          ),
          <String>[
            ...head, list, //
            '-i', '${layout.internal}/chapters.txt',
            '-r', '30', '-map', '0', '-map_chapters', '1', '-c', 'copy',
            '-metadata', 'title=September 2026',
            '-metadata', 'comment=profile=Work',
            '-metadata', 'description=clips=25;from=2026-09-01;to=2026-09-28',
            movie, '-y',
          ],
        ),
        // A movie with transitions reads its audio track as input 1 (right after the list),
        // chapters as input 2.
        (
          '${layout.name}: an audio track (D27): input 1, -map 0:v 1:a 0:s?, '
              'chapters as input 2',
          ConcatCommand.build(
            listPath: list,
            outputPath: movie,
            title: 'September 2026',
            comment: 'profile=Work',
            description:
                'clips=25;from=2026-09-01;to=2026-09-28;'
                'transition=fade',
            chaptersPath: '${layout.internal}/chapters.txt',
            audioPath: '${layout.internal}/audio.m4a',
          ),
          <String>[
            ...head, list, //
            '-i', '${layout.internal}/audio.m4a',
            '-i', '${layout.internal}/chapters.txt',
            '-r', '30', '-map', '0:v', '-map', '1:a', '-map', '0:s?',
            '-map_chapters', '2', '-c', 'copy',
            '-metadata', 'title=September 2026',
            '-metadata', 'comment=profile=Work',
            '-metadata',
            'description=clips=25;from=2026-09-01;to=2026-09-28;'
                'transition=fade',
            movie, '-y',
          ],
        ),
        (
          '${layout.name}: an audio track without chapters',
          ConcatCommand.build(
            listPath: list,
            outputPath: movie,
            comment: 'profile=',
            audioPath: '${layout.internal}/audio.m4a',
          ),
          <String>[
            ...head, list, '-i', '${layout.internal}/audio.m4a', //
            '-r', '30', '-map', '0:v', '-map', '1:a', '-map', '0:s?',
            '-c', 'copy', '-metadata', 'comment=profile=', movie, '-y',
          ],
        ),
        // A movie with music carries two audio tracks, the mix (input 1) first and default,
        // the videos' own sound (input 2) second; chapters are then input 3.
        (
          '${layout.name}: two audio tracks (D28): inputs 1 and 2, the first '
              'default, chapters as input 3',
          ConcatCommand.build(
            listPath: list,
            outputPath: movie,
            comment: 'profile=',
            description: 'clips=25;from=2026-09-01;to=2026-09-28;music=on',
            chaptersPath: '${layout.internal}/chapters.txt',
            audioPath: '${layout.internal}/mix.m4a',
            secondAudioPath: '${layout.internal}/audio.m4a',
          ),
          <String>[
            ...head, list, //
            '-i', '${layout.internal}/mix.m4a',
            '-i', '${layout.internal}/audio.m4a',
            '-i', '${layout.internal}/chapters.txt',
            '-r', '30', '-map', '0:v', '-map', '1:a', '-map', '2:a',
            '-map', '0:s?', '-map_chapters', '3', '-c', 'copy',
            '-disposition:a:0', 'default', '-disposition:a:1', '0',
            '-metadata', 'comment=profile=',
            '-metadata',
            'description=clips=25;from=2026-09-01;to=2026-09-28;music=on',
            movie, '-y',
          ],
        ),
        (
          '${layout.name}: no chapters file is the v1.7 argv, unchanged',
          ConcatCommand.build(
            listPath: list,
            outputPath: movie,
            chaptersPath: null,
          ),
          <String>[...head, list, ...copy, movie, '-y'],
        ),
      ]);
    }
    for (final (String name, List<String> argv, List<String> expected)
        in cases) {
      expect(argv, expected, reason: name);
    }
    expect(
      () => ConcatCommand.build(
        listPath: 'l',
        outputPath: 'm',
        secondAudioPath: 'second',
      ),
      throwsArgumentError,
    );
  });

  // A 60 fps movie guards against drift at its own rate; nothing else moves.
  test('a 60 fps movie: -r 60', () {
    expect(
      ConcatCommand.build(
        listPath: '/j/videos.txt',
        outputPath: '/m/OSD-Movie-3-2026-09-28.mp4',
        fps: FrameRate.f60,
        comment: 'profile=Ultra',
      ),
      <String>[
        '-f', 'concat', '-safe', '0', '-i', '/j/videos.txt', //
        '-r', '60', '-map', '0', '-c', 'copy',
        '-metadata', 'comment=profile=Ultra',
        '/m/OSD-Movie-3-2026-09-28.mp4', '-y',
      ],
    );
  });
}
