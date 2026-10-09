/// Colours as ffmpeg's drawtext reads them (`fontcolor`, `bordercolor`).
abstract final class FfmpegColor {
  /// [argb] as `0xrrggbb`, lower case, alpha dropped (the stamp has none).
  ///
  /// Masking and padding, instead of cutting the first two hex digits, also
  /// handles alpha below 0x10 and a bare `0xRRGGBB` such as
  /// `StampStyle.rgb`.
  static String hex(int argb) =>
      '0x${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
