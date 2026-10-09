import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:one_second_diary/core/l10n/display_text.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/time/local_day.dart';

/// The Places page's counts, distances and dates in the app language, over
/// the app's formatters (`LocaleFormats`: none is built in a `build`).
///
/// Numbers go through `DisplayText.safe`, as the stat values and the sheet
/// titles draw them in the display font.
final class PlacesFormats {
  const PlacesFormats._(this._formats);

  /// The formats of the app's current language.
  static PlacesFormats of(BuildContext context) =>
      PlacesFormats._(LocaleFormats.of(context));

  final LocaleFormats _formats;

  NumberFormat get numbers => _formats.numbers;

  /// "1,234".
  String number(int value) => DisplayText.safe(numbers.format(value));

  /// "45%" of [fraction] (0.45).
  String percent(double fraction) =>
      DisplayText.safe(_formats.percent.format(fraction));

  /// "1,234 km".
  String km(double km) =>
      DisplayText.safe(Strings.placesKm(km: numbers.format(km.round())));

  /// "12 clips".
  String clips(int count) => Strings.clipCount(count, format: numbers);

  /// "3 places".
  String places(int count) => Strings.placeCount(count, format: numbers);

  /// "2 countries".
  String countries(int count) =>
      Strings.placesCountryCount(count, format: numbers);

  /// "2026".
  String year(int year) =>
      DisplayText.safe(_formats.date('y').format(DateTime(year)));

  /// "Mar 12, 2026".
  String day(LocalDay day) =>
      _formats.date('yMMMd').format(day.toLocalDateTime());

  /// "Mar 12".
  String shortDay(LocalDay day) =>
      _formats.date('MMMd').format(day.toLocalDateTime());

  /// "Mar 2026".
  String month(LocalDay day) =>
      _formats.date('yMMM').format(day.toLocalDateTime());

  /// The span from [from] to [to]: one day, days of one year, or months.
  String range(LocalDay from, LocalDay to) {
    if (from == to) return day(from);
    if (from.year == to.year) {
      return Strings.placesRange(from: shortDay(from), to: day(to));
    }
    return Strings.placesRange(from: month(from), to: month(to));
  }
}
