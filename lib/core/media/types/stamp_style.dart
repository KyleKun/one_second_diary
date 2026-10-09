import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';

/// How big the texts burned into a clip are (the date and the place
/// stamps follow one size): the type size on the 1080p reference canvas,
/// scaled with the canvas like the rest of the stamp
/// (`StampFilter.fontSizeFor`).
///
/// [medium] is the 40 px every clip was ever burned with; the steps are a
/// fifth either way (32 and 48 px at 1080p). [large] stops at 48 so the
/// longest written date of a supported language ("30 de septiembre de
/// 2026", 605 px in Rubik Medium at 48) and a fourteen-letter place ("Rio
/// de Janeiro", 330 px) still share the bottom row of a 1080 px wide
/// portrait canvas between the 40 px margins, with a 65 px gap; at 54 px
/// they would overlap. The margin stays 40 px at every size: it is the
/// inset from the edge, and a wider one would eat that row.
enum StampSize {
  small(32),
  medium(40),
  large(48);

  const StampSize(this.basePx);

  /// The type size at the 1080p reference canvas, in px.
  final int basePx;

  /// The size stored as the `stampSize` preference's token
  /// (`'small'`, `'medium'`, `'large'`) and the recipe's `size`; `''`
  /// (the preference's default) and anything unknown mean [medium].
  static StampSize fromToken(String token) =>
      values.where((StampSize size) => size.name == token).firstOrNull ??
      medium;

  /// The value of the `stampSize` preference.
  String get token => name;
}

/// How the date stamp looks: format/position, colour, outline and size.
final class StampStyle extends Equatable {
  const StampStyle({
    required this.format,
    required this.rgb,
    required this.outline,
    this.size = StampSize.medium,
  });

  /// The style stored in the `dateColor`, `dateFormatId`, `dateOutline`
  /// and `stampSize` preferences.
  ///
  /// `dateColor` is `'r,g,b,a'` (0–255 each): `''`, fewer than four parts or
  /// a non-integer part mean white, each channel keeps its low 8 bits (as
  /// `Color.fromARGB` does), and alpha is ignored because the stamp has
  /// none. `stampSize` is a [StampSize] token; `''` (every install before
  /// it existed) or an unknown one means medium.
  factory StampStyle.fromPrefs({
    required String dateColor,
    required int dateFormatId,
    required bool dateOutline,
    String stampSize = '',
  }) => StampStyle(
    format: StampFormat.fromId(dateFormatId),
    rgb: _parseRgb(dateColor),
    outline: dateOutline,
    size: StampSize.fromToken(stampSize),
  );

  static const int _white = 0xFFFFFF;

  static int _parseRgb(String dateColor) {
    final List<String> parts = dateColor.split(',');
    if (parts.length < 4) return _white;
    final List<int?> channels = <int?>[
      for (final String part in parts.take(4)) int.tryParse(part),
    ];
    if (channels.contains(null)) return _white;
    final [int r, int g, int b, _] = channels.cast<int>();
    return (r & 0xFF) << 16 | (g & 0xFF) << 8 | (b & 0xFF);
  }

  final StampFormat format;

  /// Text colour as `0xRRGGBB` (the stamp has no alpha).
  final int rgb;

  /// Whether the text gets a 1 px outline in the inverted colour.
  final bool outline;

  /// How big the date and the place are burned; medium unless chosen.
  final StampSize size;

  /// The values for the `dateColor`, `dateFormatId`, `dateOutline` and
  /// `stampSize` preferences. The colour is written opaque (`…,255`); the
  /// size as its token (`'medium'`, never `''`).
  ({String dateColor, int dateFormatId, bool dateOutline, String stampSize})
  toPrefs() => (
    dateColor: '${rgb >> 16 & 0xFF},${rgb >> 8 & 0xFF},${rgb & 0xFF},255',
    dateFormatId: format.id,
    dateOutline: outline,
    stampSize: size.token,
  );

  @override
  List<Object?> get props => <Object?>[format, rgb, outline, size];
}
