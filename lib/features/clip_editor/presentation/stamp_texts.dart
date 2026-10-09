import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/media/policy/date_stamp.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/time/local_day.dart';

/// The date stamp's text as the export burns it (`DateStamp.text`: the
/// localised numeric or written date of the day the clip is filed under),
/// in the app language with the phone's region.
///
/// Each text is formatted once per day, format and locale, so a build never
/// constructs a `DateFormat` twice.
abstract final class StampTexts {
  static final Map<(int, StampFormat, String), String> _cache =
      <(int, StampFormat, String), String>{};

  /// The stamp of [day] in [format] for the app language of [context].
  static String of(
    BuildContext context, {
    required LocalDay day,
    required StampFormat format,
  }) {
    final Locale device = WidgetsBinding.instance.platformDispatcher.locale;
    final String locale = DateStamp.displayLocale(
      appLanguage: Localizations.localeOf(context).languageCode,
      deviceLanguage: device.languageCode,
      deviceRegion: device.countryCode,
    );
    return _cache.putIfAbsent((
      day.key,
      format,
      locale,
    ), () => DateStamp.text(day, format: format, locale: locale));
  }
}
