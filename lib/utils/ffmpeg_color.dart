import 'dart:ui';

/// Formats colors the way ffmpeg's drawtext filter reads them.
class FFmpegColor {
  FFmpegColor._();

  /// [color] as `0xRRGGBB`. Alpha is left out, the stamp is always drawn
  /// opaque. The digits are zero-padded: cutting the alpha digits off the
  /// whole ARGB value instead broke on colors whose alpha is below 0x10,
  /// e.g. a transparent black came out as "0" and threw a RangeError.
  static String hex(Color color) =>
      '0x${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
