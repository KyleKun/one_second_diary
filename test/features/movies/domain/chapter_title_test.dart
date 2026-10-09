import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/movies/domain/chapter_title.dart';

void main() {
  setUpAll(initializeDateFormatting);

  final LocalDay day = LocalDay(2023, 8, 27);

  test('a clip is titled with its day in the app language (the long date, '
      'as the written stamp); a language intl has no data for, or none, '
      'is written in US English', () {
    expect(ChapterTitle.of(day: day, locale: 'en'), 'August 27, 2023');
    expect(ChapterTitle.of(day: day, locale: 'pt'), '27 de agosto de 2023');
    expect(ChapterTitle.of(day: day, locale: 'zh'), '2023年8月27日');
    expect(ChapterTitle.of(day: day, locale: null), 'August 27, 2023');
    expect(ChapterTitle.of(day: day, locale: 'xx'), 'August 27, 2023');
  });

  test('a day with several clips in the movie numbers them; the place and '
      'the first line of the subtitle follow, each left out when blank', () {
    expect(
      ChapterTitle.of(day: day, locale: 'en', position: 2, sameDay: 3),
      'August 27, 2023 (2)',
    );
    expect(
      ChapterTitle.of(day: day, locale: 'en', position: 1, sameDay: 1),
      'August 27, 2023',
    );
    expect(
      ChapterTitle.of(
        day: day,
        locale: 'en',
        position: 1,
        sameDay: 2,
        place: ' Berlin ',
        subtitle: 'eating bananas\nwith friends',
      ),
      'August 27, 2023 (1) · Berlin · eating bananas',
    );
    expect(
      ChapterTitle.of(day: day, locale: 'en', place: '', subtitle: '  \n '),
      'August 27, 2023',
    );
    expect(
      ChapterTitle.of(day: day, locale: 'en', subtitle: '\n\nlate start'),
      'August 27, 2023 · late start',
    );
  });

  test('a title is at most ${ChapterTitle.maxLength} characters, ending in '
      'an ellipsis when cut', () {
    final String title = ChapterTitle.of(
      day: day,
      locale: 'en',
      place: 'Berlin',
      subtitle: 'x' * 200,
    );

    expect(title.length, ChapterTitle.maxLength);
    expect(title, startsWith('August 27, 2023 · Berlin · xxx'));
    expect(title, endsWith('x…'));
  });
}
