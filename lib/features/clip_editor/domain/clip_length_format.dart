import 'package:intl/intl.dart';

/// How the clip editor writes a clip length, for one locale: the trim
/// readout and the seconds its semantics read aloud.
///
/// Made once per locale ([ClipLengthFormat.of] caches it), so a build never
/// creates a `NumberFormat`.
final class ClipLengthFormat {
  ClipLengthFormat._(String locale)
    : _number = NumberFormat.decimalPattern(locale)..maximumFractionDigits = 2;

  /// The format for the intl [locale] (e.g. `en`, `pt_BR`); a locale intl
  /// has no data for formats as English.
  factory ClipLengthFormat.of(String locale) => _cache.putIfAbsent(
    locale,
    () => ClipLengthFormat._(NumberFormat.localeExists(locale) ? locale : 'en'),
  );

  static final Map<String, ClipLengthFormat> _cache =
      <String, ClipLengthFormat>{};

  /// .990 s and more shows as the next second, so a clip a hair short of a
  /// second reads 01.00.
  static const int _roundUpFromMs = 990;

  final NumberFormat _number;

  String get _separator => _number.symbols.DECIMAL_SEP;

  /// The readout: zero-padded seconds, the locale's decimal separator, then
  /// hundredths ("01.50" for 1.5 s, "01,50" in German).
  String readout(int ms) {
    final int shown = ms % 1000 >= _roundUpFromMs
        ? (ms ~/ 1000 + 1) * 1000
        : ms;
    final String seconds = (shown ~/ 1000).toString().padLeft(2, '0');
    final String hundredths = (shown % 1000 ~/ 10).toString().padLeft(2, '0');
    return '$seconds$_separator$hundredths';
  }

  /// [ms] as seconds for a sentence ("1.5", "1,5"), at most two decimals.
  String seconds(int ms) => _number.format(ms / 1000);

  /// The format of [seconds], for a plural string that shows them
  /// (`Strings.saveVideoClipLengthSemantics(ms / 1000, format: …)`).
  NumberFormat get secondsFormat => _number;

  /// Whether a length of [seconds] reads as minutes and seconds: past 59 s
  /// (the camera's chip and its settings sheet show "1:00", not "60 s").
  static bool showsMinutes(int seconds) => seconds > 59;

  /// A length of [seconds] as minutes and seconds ("1:00"), in Western
  /// digits as the timer pill: for lengths [showsMinutes].
  static String minutes(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
