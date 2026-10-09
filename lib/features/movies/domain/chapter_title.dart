import 'package:intl/intl.dart';
import 'package:one_second_diary/core/time/local_day.dart';

/// The title of a clip's chapter in a movie: its day, its number on that day
/// when the day has more than one clip in the movie, its place and the first
/// line of its subtitle, in that order, `August 27, 2023 (2) · Berlin · eating
/// bananas with friends`.
abstract final class ChapterTitle {
  /// The most characters a title has; a longer one is cut and ends with
  /// an ellipsis.
  static const int maxLength = 120;

  /// Between the date, the place and the subtitle.
  static const String separator = ' · ';

  static const String _ellipsis = '…';

  /// The title of the clip of [day] in the intl [locale] (null or a locale intl
  /// has no data for formats as US English), the [position]th (1-based) of the
  /// day's [sameDay] clips in the movie, at [place] and with [subtitle]: a
  /// blank place or subtitle is left out, and only the subtitle's first line is
  /// used.
  static String of({
    required LocalDay day,
    required String? locale,
    int position = 1,
    int sameDay = 1,
    String? place,
    String? subtitle,
  }) {
    final StringBuffer title = StringBuffer(_date(day, locale: locale));
    if (sameDay > 1) title.write(' ($position)');
    final String? where = _clean(place);
    if (where != null) title.write('$separator$where');
    final String? said = _firstLine(subtitle);
    if (said != null) title.write('$separator$said');
    return _capped(title.toString());
  }

  static String _date(LocalDay day, {required String? locale}) {
    final String tag = locale != null && DateFormat.localeExists(locale)
        ? locale
        : 'en_US';
    final DateFormat format = _dates[tag] ??= DateFormat.yMMMMd(tag);
    // Only the date fields matter; UTC keeps a DST change out of it.
    return format.format(DateTime.utc(day.year, day.month, day.day));
  }

  /// One format per locale: a `DateFormat` per clip is measurably slow in
  /// a movie of thousands.
  static final Map<String, DateFormat> _dates = <String, DateFormat>{};

  static String? _clean(String? text) => switch (text?.trim()) {
    final String clean when clean.isNotEmpty => clean,
    _ => null,
  };

  static String? _firstLine(String? text) =>
      _clean(text?.trim().split(_lineBreak).first);

  static final RegExp _lineBreak = RegExp('[\\r\\n  ]');

  static String _capped(String title) => title.length <= maxLength
      ? title
      : '${title.substring(0, maxLength - _ellipsis.length).trimRight()}'
            '$_ellipsis';
}
