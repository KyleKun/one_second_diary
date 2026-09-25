import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class DateFormatUtils {
  /// Today as `yyyy-MM-dd`, the format video file names use.
  static String getToday() => getDate(DateTime.now());

  /// [date] as `yyyy-MM-dd`, the format video file names use. Never
  /// localized: the calendar, movie creation and video count all find
  /// videos by this exact name.
  static String getDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  /// The `intl` locale dates are shown in: the app language, plus the
  /// device's region when the device uses that same language — so English
  /// is month-first in the US but day-first in the UK, and Portuguese
  /// follows Brazil or Portugal.
  static String _displayLocale() {
    final String language = Get.locale?.languageCode ?? 'en';
    final Locale? device = Get.deviceLocale;
    final String? region = device?.countryCode;
    if (device?.languageCode == language && region != null) {
      final String withRegion = '${language}_$region';
      if (DateFormat.localeExists(withRegion)) return withRegion;
    }
    return DateFormat.localeExists(language) ? language : 'en';
  }

  /// [date] in the numeric form burned into videos, e.g. `02/06/2024` in
  /// the US, `06.02.2024` in German, `2024. 02. 06.` in Hungarian.
  static String getNumericDate(DateTime date) =>
      formatNumericDate(date, _displayLocale());

  /// [date] written out as burned into videos, e.g. `February 6, 2024` in
  /// the US, `6. Februar 2024` in German, `2024年2月6日` in Chinese.
  static String getWrittenDate(DateTime date) =>
      formatWrittenDate(date, _displayLocale());

  /// A video's `yyyy-MM-dd` file name (without extension) shown as
  /// [getNumericDate]. Returned unchanged if it isn't a valid date.
  static String displayDateFromFileName(String fileName) {
    final DateTime? date = DateTime.tryParse(fileName);
    return date == null ? fileName : getNumericDate(date);
  }

  /// [locale]'s own short date order and separators, zero-padded so the
  /// stamp keeps the same width every day (`d/M/y` becomes `dd/MM/yyyy`).
  @visibleForTesting
  static String formatNumericDate(DateTime date, String locale) {
    final String pattern = DateFormat.yMd(locale).pattern!.replaceAllMapped(
      RegExp('d+|M+|y+'),
      (match) => match[0]!.startsWith('y') ? 'yyyy' : match[0]![0] * 2,
    );
    return _stampSafe(DateFormat(pattern, locale).format(date));
  }

  /// [locale]'s own long date, month name included.
  @visibleForTesting
  static String formatWrittenDate(DateTime date, String locale) =>
      _stampSafe(DateFormat.yMMMMd(locale).format(date));

  /// Order the dates before writing the txt file for generating movie
  static List<DateTime> orderDates(List<DateTime> dates) {
    dates.sort((a, b) {
      return a.compareTo(b);
    });
    return dates;
  }

  /// Swaps characters the stamp fonts draw badly for plain ones: no-break
  /// spaces (e.g. Russian's `2024 г.`), which the trimmed Noto Sans lacks
  /// and a stamp never wraps on anyway, and Catalan's typographic
  /// apostrophe (`d’abril`), which YuseiMagic draws as a full-width glyph.
  static String _stampSafe(String text) =>
      text.replaceAll(RegExp('[\u00a0\u202f]'), ' ').replaceAll('\u2019', "'");
}
