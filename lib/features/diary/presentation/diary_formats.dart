import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';

/// The Diary's dates and numbers in one language, over the app's
/// formatters (`LocaleFormats`, made once per language): a grid build
/// formats with them and never constructs a `DateFormat`.
///
/// Read it in `build` with [of], which depends on the app's locale, so a
/// language change rebuilds the Diary with the new formats.
final class DiaryFormats {
  const DiaryFormats._(this._formats);

  /// The formats of the app's current language.
  static DiaryFormats of(BuildContext context) =>
      DiaryFormats._(LocaleFormats.of(context));

  /// The formats of [tag] (`en`, `pt`, …). A language intl has no data for
  /// uses the app default (`Intl.defaultLocale`, always an app language).
  static DiaryFormats forLocale(String tag) =>
      DiaryFormats._(LocaleFormats.forLocale(tag));

  final LocaleFormats _formats;

  /// Day numbers and counts.
  NumberFormat get numbers => _formats.numbers;

  /// The narrow weekday names, Sunday first ("S M T W T F S").
  List<String> get narrowWeekdays => _formats.symbols.STANDALONENARROWWEEKDAYS;

  /// "September 2026", sentence-cased (es, pt and ru write months in lower
  /// case).
  String monthTitle(DiaryMonth month) => toBeginningOfSentenceCase(
    _formats.date('yMMMM').format(month.first.toLocalDateTime()),
    _formats.locale,
  );

  /// "Wednesday, September 16": how screen readers name a day.
  String fullDate(LocalDay day) =>
      _formats.date('MMMMEEEEd').format(day.toLocalDateTime());

  /// "Wednesday": the caption's weekday (`diaryDayCaption`).
  String weekday(LocalDay day) =>
      _formats.date('EEEE').format(day.toLocalDateTime());

  /// "16": the caption's day of the month (`diaryDayCaption`).
  String dayOfMonth(LocalDay day) =>
      _formats.date('d').format(day.toLocalDateTime());
}
