import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:one_second_diary/core/l10n/display_text.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';

/// The Journey tab's numbers, dates and durations in the app language,
/// through the app's formatters (`LocaleFormats`: none is built in a
/// `build`).
///
/// Every string drawn in a display style goes through `DisplayText.safe`:
/// intl groups a French 1 000 with U+202F, which Yusei Magic lacks.
abstract final class JourneyFormats {
  /// The number format of [context]'s locale ("1,234").
  static NumberFormat numberFormat(BuildContext context) =>
      LocaleFormats.of(context).numbers;

  /// [value] as the locale writes it, safe for display text.
  static String number(BuildContext context, int value) =>
      DisplayText.safe(numberFormat(context).format(value));

  /// A duration as the Journey draws it: its largest unit big and the next
  /// one small, "15 min" + "14 s", "2 h" + "14 min", or "45 s" alone under
  /// a minute.
  static ({String primary, String? secondary}) duration(int seconds) {
    if (seconds < 60) {
      return (
        primary: Strings.durationSecondsShort(count: seconds),
        secondary: null,
      );
    }
    if (seconds < 3600) {
      return (
        primary: Strings.durationMinutesShort(count: seconds ~/ 60),
        secondary: Strings.durationSecondsShort(count: seconds % 60),
      );
    }
    return (
      primary: Strings.durationHoursShort(count: seconds ~/ 3600),
      secondary: Strings.durationMinutesShort(count: seconds % 3600 ~/ 60),
    );
  }

  /// [seconds] as its two largest units in words, for screen readers:
  /// "15 minutes 14 seconds", "2 hours 14 minutes", "45 seconds".
  static String durationSpoken(int seconds) {
    if (seconds < 60) return Strings.journeyDurationSeconds(seconds);
    if (seconds < 3600) {
      return Strings.journeyDurationPair(
        larger: Strings.journeyDurationMinutes(seconds ~/ 60),
        smaller: Strings.journeyDurationSeconds(seconds % 60),
      );
    }
    return Strings.journeyDurationPair(
      larger: Strings.journeyDurationHours(seconds ~/ 3600),
      smaller: Strings.journeyDurationMinutes(seconds % 3600 ~/ 60),
    );
  }
}
