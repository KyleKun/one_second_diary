import 'package:intl/intl.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/time/local_day.dart';

/// The date text burned into a clip.
///
/// The stamp is for the day the clip is FILED under, never "now".
/// Needs `initializeDateFormatting()` (intl) before the first call.
abstract final class DateStamp {
  /// The stamp text of [day] in [format], for the intl [locale] (see
  /// [displayLocale]).
  static String text(
    LocalDay day, {
    required StampFormat format,
    required String locale,
  }) => switch (format) {
    StampFormat.numeric => numeric(day, locale: locale),
    StampFormat.written => written(day, locale: locale),
  };

  /// [locale]'s own short date order and separators, zero-padded so the stamp
  /// keeps the same width every day (`d/M/y` becomes `dd/MM/yyyy`), e.g.
  /// `02/06/2024` (en_US), `06.02.2024` (de), `2024. 02. 06.` (hu).
  static String numeric(LocalDay day, {required String locale}) {
    final String pattern = DateFormat.yMd(locale).pattern!.replaceAllMapped(
      _patternFields,
      (Match match) => match[0]!.startsWith('y') ? 'yyyy' : match[0]![0] * 2,
    );
    return _stampSafe(DateFormat(pattern, locale).format(_date(day)));
  }

  /// [locale]'s long date with the month name (CLDR `yMMMMd`, no ordinals),
  /// e.g. `February 6, 2024`, `6 февраля 2024 г.`, `2024年2月6日`.
  static String written(LocalDay day, {required String locale}) =>
      _stampSafe(DateFormat.yMMMMd(locale).format(_date(day)));

  /// The intl locale stamps are written in: the app language, plus the
  /// device's region when the device uses that same language, so English is
  /// month-first in the US but day-first in the UK, and Portuguese follows
  /// Brazil or Portugal. A region intl has no data for is dropped, and a
  /// language it does not know (or none) falls back to `en`.
  ///
  /// [appLanguage] is the app's language code; [deviceLanguage] and
  /// [deviceRegion] are the device locale's parts.
  static String displayLocale({
    required String? appLanguage,
    required String? deviceLanguage,
    required String? deviceRegion,
  }) {
    final String language = appLanguage ?? 'en';
    if (deviceLanguage == language && deviceRegion != null) {
      final String withRegion = '${language}_$deviceRegion';
      if (DateFormat.localeExists(withRegion)) return withRegion;
    }
    return DateFormat.localeExists(language) ? language : 'en';
  }

  static final RegExp _patternFields = RegExp('d+|M+|y+');

  /// Only the date fields matter; UTC keeps a DST change out of it.
  static DateTime _date(LocalDay day) =>
      DateTime.utc(day.year, day.month, day.day);

  /// Swaps characters the stamp fonts draw badly for plain ones: no-break
  /// spaces (Russian's `2024 г.`), which the trimmed Noto Sans lacks and a
  /// stamp never wraps on anyway, and Catalan's typographic apostrophe
  /// (`d’abril`), which YuseiMagic draws as a full-width glyph.
  static String _stampSafe(String text) =>
      text.replaceAll(RegExp('[\u00A0\u202F]'), ' ').replaceAll('’', "'");
}
