import 'package:get/get.dart';

import 'constants.dart';
import 'extensions.dart';

class DateFormatUtils {
  /// Add ['st', 'nd' or 'st'] for date in text format if it is in English
  static String getEnglishDaySuffix(String day) {
    switch (day) {
      case '1':
        return 'st';
      case '21':
        return 'st';
      case '31':
        return 'st';
      case '2':
        return 'nd';
      case '22':
        return 'nd';
      case '3':
        return 'rd';
      case '23':
        return 'rd';
      default:
        return 'th';
    }
  }

  /// Get current date for editting video with date in text format
  static String getWrittenToday({DateTime? customDate, String lang = ''}) {
    List<String> date = [];
    if (customDate == null) {
      date = getToday().split('-');
    } else {
      date = getDate(customDate).split('-');
    }

    final String year = date.first;
    // Used to get month index in list
    final int monthNumber = int.parse(date[1]);

    String day = date.last;
    String month = '';

    if (lang == 'es') {
      month = Constants.esMonths[monthNumber - 1];
      return '$day de $month de $year';
    }
    if (lang == 'pt') {
      month = Constants.ptMonths[monthNumber - 1];
      return '$day de $month de $year';
    }
    // Default format for English and other languages
    month = Constants.enMonths[monthNumber - 1];
    // Used to remove leading 0
    day = int.parse(day).toString();
    // Day suffix
    final String suffix = getEnglishDaySuffix(day);
    return '$month $day$suffix, $year';
  }

  /// Applied if language is ['pt' or 'es']
  static bool isDayFirstPattern() {
    final String languageCode = Get.locale!.languageCode;
    if (languageCode == 'pt' || languageCode == 'es') {
      return true;
    }
    return false;
  }

  /// Get the current date and format it properly
  static String getToday({bool allowCheckFormattingDayFirst = false}) {
    final now = DateTime.now();

    // Adding a leading zero on Days and Months <= 9
    final String day = now.day <= 9 ? '0${now.day}' : '${now.day}';
    final String month = now.month <= 9 ? '0${now.month}' : '${now.month}';
    final String year = '${now.year}';

    // Brazilian pattern
    if (allowCheckFormattingDayFirst) {
      if (isDayFirstPattern()) {
        return '$day-$month-$year';
      }
    }

    return '$year-$month-$day';
  }

  /// Get the given date and format it properly
  static String getDate(DateTime date, {bool allowCheckFormattingDayFirst = false}) {
    // Adding a leading zero on Days and Months <= 9
    final String day = date.day <= 9 ? '0${date.day}' : '${date.day}';
    final String month = date.month <= 9 ? '0${date.month}' : '${date.month}';
    final String year = '${date.year}';

    // Brazilian pattern
    if (allowCheckFormattingDayFirst) {
      if (isDayFirstPattern()) {
        return '$day-$month-$year';
      }
    }

    return '$year-$month-$day';
  }

  static String parseDateStringAccordingLocale(String date) {
    if (isDayFirstPattern()) {
      final String year = date.split('-').first;
      final String month = date.split('-')[1];
      final String day = date.split('-').last;
      return '$day-$month-$year';
    }

    return date;
  }

  /// Convert the given date from the app's ffmpeg friendly format to DateTime
  static DateTime parseToDateTime(String date, {bool? isDayFirst}) {
    isDayFirst ??= isDayFirstPattern();

    final String day = isDayFirst ? date.split('-').first : date.split('-').last;
    final String month = date.split('-')[1];
    final String year = isDayFirst ? date.split('-').last : date.split('-').first;

    return DateTime(year.toInt(), month.toInt(), day.toInt());
  }

  /// Order the dates before writing the txt file for generating movie
  static List<DateTime> orderDates(List<DateTime> dates) {
    dates.sort((a, b) {
      return a.compareTo(b);
    });
    return dates;
  }
}
