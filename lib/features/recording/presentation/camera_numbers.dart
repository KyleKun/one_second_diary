import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';

/// Numbers on the camera (the clip length, the countdown) in the app
/// language's digits, through the app's formatters (never built in
/// `build`).
abstract final class CameraNumbers {
  static NumberFormat of(BuildContext context) =>
      LocaleFormats.of(context).numbers;

  /// A length of the timer pill, "00:07": minutes and seconds, two digits
  /// each, in Western digits.
  static String clock(int seconds) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(seconds ~/ 60)}:${two(seconds % 60)}';
  }
}
