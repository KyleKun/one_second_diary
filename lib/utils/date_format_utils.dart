import 'dart:ui' as ui;
import 'package:get/get.dart';
import 'constants.dart';

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
  static String getWrittenToday({String lang = ''}) {
    final date = getToday().split('-');

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
    day = (int.parse(day)).toString();
    // Day suffix
    final String suffix = getEnglishDaySuffix(day);
    return '$month $day$suffix, $year';
  }

  /// Applied if language is ['pt' or 'es']
  static bool isDayFirstPattern() {
    if (Get.locale!.languageCode == 'pt') {
      return true;
    }
    if (Get.locale!.languageCode == 'es') {
      return true;
    }
    if (ui.window.locale.countryCode == 'BR') {
      return true;
    }
    return false;
  }

  /// Get the current date and format it properly
  static String getToday({bool isDayFirst = false}) {
    final now = DateTime.now();

    // Adding a leading zero on Days and Months <= 9
    final String day = now.day <= 9 ? '0${now.day}' : '${now.day}';
    final String month = now.month <= 9 ? '0${now.month}' : '${now.month}';
    final String year = '${now.year}';

    // Brazilian pattern
    if (isDayFirst) {
      return '$day-$month-$year';
    } else {
      return '$year-$month-$day';
    }
  }

  /// Order the dates before writing the txt file for generating movie
  static List<DateTime> orderDates(List<DateTime> dates) {
    dates.sort((a, b) {
      return a.compareTo(b);
    });
    return dates;
  }
}
