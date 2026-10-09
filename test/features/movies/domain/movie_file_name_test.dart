import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/movies/domain/movie_file_name.dart';

void main() {
  test('writes and counts only v1.7 names, OSD-Movie-<n>-<yyyy-MM-dd>.mp4; a '
      'number past 64 bits never counts', () {
    expect(
      MovieFileName.format(number: 3, day: LocalDay(2026, 9, 28)),
      'OSD-Movie-3-2026-09-28.mp4',
    );

    final Map<String, int?> numbers = <String, int?>{
      'OSD-Movie-12-2024-01-05.mp4': 12,
      'OSD-Movie-999999999999999999-2024-01-05.mp4': 999999999999999999,
      'OneSecondDiary-Movie-4-2022-01-01.mp4': null, // older installs
      'OSD-Movie-12-2024-02-30.mp4': null, // impossible date
      'OSD-Movie-12-2024-01-05 (1).mp4': null, // a file manager's copy
      'OSD-Movie-12-2024-01-05.MP4': null,
      'OSD-Movie--2024-01-05.mp4': null,
      '.trashed-1700000000-OSD-Movie-12-2024-01-05.mp4': null,
      'Summer in Japan.mp4': null,
      'OSD-Movie-99999999999999999999-2024-01-05.mp4': null, // past 64 bits
      'OSD-Movie-9223372036854775807-2024-01-05.mp4': null, // + 1 wraps
    };
    for (final MapEntry<String, int?>(key: String name, value: int? number)
        in numbers.entries) {
      expect(MovieFileName.numberOf(name), number, reason: name);
    }
  });

  test('reads the day in every name the app ever gave a movie, and none in '
      'other names or impossible dates', () {
    final Map<String, LocalDay?> days = <String, LocalDay?>{
      'OSD-Movie-12-2024-01-05.mp4': LocalDay(2024, 1, 5),
      // Named by older installs.
      'OneSecondDiary-Movie-4-2022-01-01.mp4': LocalDay(2022, 1, 1),
      // The oldest installs' names have no number.
      'OneSecondDiary-Movie-2021-02-27.mp4': LocalDay(2021, 2, 27),
      'OSD-Movie-12-2024-02-30.mp4': null,
      'OSD-Movie-2024-01-05.mp4': null,
      'Summer in Japan.mp4': null,
      '2024-01-05.mp4': null,
    };
    for (final MapEntry<String, LocalDay?>(key: String name, value: day)
        in days.entries) {
      expect(MovieFileName.dayOf(name), day, reason: name);
    }
  });
}
