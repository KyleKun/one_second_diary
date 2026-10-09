import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/ffmetadata_chapters.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';

void main() {
  // The file ffmpeg reads with `-map_chapters 1`.
  test('encodes one [CHAPTER] per chapter in milliseconds, escaping what '
      'ffmetadata treats as syntax (= ; # \\) and keeping a title on one '
      'line: line breaks become a space, other control characters go', () {
    final String text = FfmetadataChapters.encode(const <MovieChapter>[
      MovieChapter(
        startMs: 0,
        endMs: 1500,
        title: 'August 27, 2023 · Berlin · eating bananas ; with friends',
      ),
      MovieChapter(
        startMs: 1500,
        endMs: 2500,
        title: 'a=b #1 c\\d\nsecond line\r\ntab\there\u0000\u0007\u009F',
      ),
    ]);

    expect(
      text,
      ';FFMETADATA1\n'
      '[CHAPTER]\n'
      'TIMEBASE=1/1000\n'
      'START=0\n'
      'END=1500\n'
      'title=August 27, 2023 · Berlin · eating bananas \\; with friends\n'
      '[CHAPTER]\n'
      'TIMEBASE=1/1000\n'
      'START=1500\n'
      'END=2500\n'
      'title=a\\=b \\#1 c\\\\d second line  tab here\n',
    );
    expect(FfmetadataChapters.encode(const <MovieChapter>[]), ';FFMETADATA1\n');
  });

  test('lays the clips end to end from 0: each chapter starts where the one '
      'before ends, the last ends at the total; a clip without a title '
      'takes its time but makes no chapter', () {
    expect(
      FfmetadataChapters.boundaries(const <({String? title, int durationMs})>[
        (title: 'day 1', durationMs: 1500),
        (title: 'day 2', durationMs: 1000),
        (title: null, durationMs: 700),
        (title: 'day 4', durationMs: 2000),
      ]),
      const <MovieChapter>[
        MovieChapter(startMs: 0, endMs: 1500, title: 'day 1'),
        MovieChapter(startMs: 1500, endMs: 2500, title: 'day 2'),
        MovieChapter(startMs: 3200, endMs: 5200, title: 'day 4'),
      ],
    );
    expect(
      FfmetadataChapters.boundaries(const <({String? title, int durationMs})>[
        (title: null, durationMs: 1500),
        (title: null, durationMs: 1500),
      ]),
      isEmpty,
    );
  });
}
