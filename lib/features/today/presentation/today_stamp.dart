import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/media/policy/date_stamp.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/time/local_day.dart';

/// The date stamp as the video will burn it, for Today's previews: the
/// user's [format], in the app language with the phone's region
/// (`DateStamp.displayLocale`).
abstract final class TodayStamp {
  static String locale(BuildContext context) {
    final Locale device = View.of(context).platformDispatcher.locale;
    return DateStamp.displayLocale(
      appLanguage: Localizations.localeOf(context).languageCode,
      deviceLanguage: device.languageCode,
      deviceRegion: device.countryCode,
    );
  }

  static String of(
    BuildContext context, {
    required LocalDay day,
    required StampFormat format,
  }) => DateStamp.text(day, format: format, locale: locale(context));
}
