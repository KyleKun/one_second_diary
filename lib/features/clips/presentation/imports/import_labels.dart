import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';

/// The words of the import and backup sheets: counts, lengths and sizes in
/// the app language (shared with the movie flow's labels, which delegate
/// here for the length).
abstract final class ImportLabels {
  /// Counts as the locale writes them ("1,234").
  static NumberFormat numberFormat(BuildContext context) =>
      LocaleFormats.of(context).numbers;

  /// [time] in round words: "45 s" under a minute, "12 min" under an hour
  /// (rounded to the minute, never "0 min"), else "2 h 14 min".
  static String roughDuration(Duration time) {
    final int seconds = time.inSeconds < 0 ? 0 : time.inSeconds;
    if (seconds < 60) return Strings.durationSecondsShort(count: seconds);
    final int minutes = (seconds / 60).round();
    if (minutes < 60) return Strings.durationMinutesShort(count: minutes);
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    final String h = Strings.durationHoursShort(count: hours);
    return rest == 0 ? h : '$h ${Strings.durationMinutesShort(count: rest)}';
  }

  /// [bytes] as the phone's settings show sizes, rounded up so what it
  /// says to free is enough: "850 MB", "1.3 GB" (1 000-based, one decimal
  /// from a gigabyte on).
  static String size(BuildContext context, int bytes) {
    const int megabyte = 1000 * 1000;
    const int gigabyte = 1000 * megabyte;
    if (bytes < gigabyte) {
      final int megabytes = (bytes / megabyte).ceil();
      return Strings.movieSizeMegabytes(
        size: numberFormat(context).format(megabytes < 1 ? 1 : megabytes),
      );
    }
    final double gigabytes = (bytes / gigabyte * 10).ceil() / 10;
    return Strings.movieSizeGigabytes(
      size: LocaleFormats.of(context).pattern('#,##0.#').format(gigabytes),
    );
  }

  /// "1.5 s", "2 s".
  static String seconds(int ms) {
    final double seconds = ms / 1000;
    final String text = seconds == seconds.roundToDouble()
        ? '${seconds.round()}'
        : seconds.toStringAsFixed(1);
    return Strings.secondsValue(seconds: text);
  }
}
