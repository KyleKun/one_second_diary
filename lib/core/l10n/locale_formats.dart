import 'package:flutter/widgets.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart';

/// The app language's intl formatters, made once per language and kept:
/// screens format numbers, dates and times with these and never build a
/// `DateFormat` or `NumberFormat` in `build`.
///
/// Read them in `build` with [of], which depends on the app's locale, so a
/// language change rebuilds with the new formats. A string drawn in the
/// display font goes through `DisplayText.safe` too.
///
/// ```dart
/// final LocaleFormats formats = LocaleFormats.of(context);
/// formats.date('yMMMd').format(day);   // "Sep 28, 2026" (an intl skeleton)
/// formats.numbers.format(1234);        // "1,234"
/// ```
final class LocaleFormats {
  LocaleFormats._(this.locale)
    : _numberLocale = NumberFormat.localeExists(locale) ? locale : null;

  /// The formats of the app's current language.
  static LocaleFormats of(BuildContext context) =>
      forLocale(Localizations.localeOf(context).toLanguageTag());

  /// The formats of [tag] (`en`, `pt`, …), made once.
  static LocaleFormats forLocale(String tag) =>
      _made[tag] ??= LocaleFormats._(tag);

  static final Map<String, LocaleFormats> _made = <String, LocaleFormats>{};

  /// The language (`en`, `pt`, …).
  final String locale;

  /// [locale] when intl has its numbers (always, for the app's languages);
  /// null (the default language) otherwise.
  final String? _numberLocale;

  final Map<String, DateFormat> _dates = <String, DateFormat>{};
  final Map<String, NumberFormat> _patterns = <String, NumberFormat>{};

  /// Counts as the language writes them ("1,234").
  late final NumberFormat numbers = NumberFormat.decimalPattern(_numberLocale);

  /// A fraction as a whole percent ("45%", "45 %", "%45").
  late final NumberFormat percent = NumberFormat.percentPattern(_numberLocale);

  /// The number format of [pattern] ("#,##0.#").
  NumberFormat pattern(String pattern) =>
      _patterns[pattern] ??= NumberFormat(pattern, _numberLocale);

  /// The date format of the intl [skeleton] (`DateFormat.yMMMd` is
  /// `'yMMMd'`), or of a pattern of its own.
  ///
  /// Dates need the language's data, which the launch loads before the
  /// first frame (`initializeDateFormatting`). Until then, and for a
  /// language intl has no data for, the default language formats it, and
  /// that format is not kept.
  DateFormat date(String skeleton) {
    final DateFormat? made = _dates[skeleton];
    if (made != null) return made;
    if (!DateFormat.localeExists(locale)) return DateFormat(skeleton);
    return _dates[skeleton] = DateFormat(skeleton, locale);
  }

  /// The language's month and weekday names.
  DateSymbols get symbols => date('d').dateSymbols;
}
