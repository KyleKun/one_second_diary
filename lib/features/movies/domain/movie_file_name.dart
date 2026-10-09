import 'package:one_second_diary/core/time/local_day.dart';

/// Names of the files in `Movies/`.
abstract final class MovieFileName {
  /// At most 18 digits: every such number and its successor fit in 64 bits, so
  /// reading one never throws and the next movie number never wraps around.
  static final RegExp _current = RegExp(
    r'^OSD-Movie-(\d{1,18})-(\d{4}-\d{2}-\d{2})\.mp4$',
  );

  static final RegExp _any = RegExp(
    r'^(?:OSD-Movie-\d+|OneSecondDiary-Movie(?:-\d+)?)-(\d{4}-\d{2}-\d{2})\.mp4$',
  );

  /// `OSD-Movie-<number>-<yyyy-MM-dd>.mp4`, with [day] the day it was made.
  static String format({required int number, required LocalDay day}) =>
      'OSD-Movie-$number-${day.fileStem}.mp4';

  /// The number of a [format] name; null for any other name.
  static int? numberOf(String fileName) {
    final RegExpMatch? match = _current.firstMatch(fileName);
    if (match == null || LocalDay.tryParseStem(match.group(2)!) == null) {
      return null;
    }
    return int.parse(match.group(1)!);
  }

  /// The day in the name of a movie the app made, in any of its three
  /// namings; null for any other name or an impossible date.
  static LocalDay? dayOf(String fileName) {
    final RegExpMatch? match = _any.firstMatch(fileName);
    return match == null ? null : LocalDay.tryParseStem(match.group(1)!);
  }

  /// The title of a movie the movie index knows nothing about (made by an older
  /// install, or copied in): the `yyyy-MM-dd` day in its name, else the name
  /// without `.mp4`.
  static String titleOf(String fileName) =>
      dayOf(fileName)?.fileStem ??
      (fileName.endsWith('.mp4')
          ? fileName.substring(0, fileName.length - 4)
          : fileName);
}
