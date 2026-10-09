import 'dart:ui' show FontWeight;

import 'package:one_second_diary/core/media/policy/stamp_font_coverage.g.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

/// The fonts ffmpeg burns the date and location stamps with.
///
/// ffmpeg's drawtext has no per-glyph fallback (it draws empty boxes), so
/// one font is chosen for a clip's stamps from their text
/// (`StampFontPolicy`). Previews must use [flutterFamily] at [flutterWeight]
/// so they match.
enum StampFont {
  /// Rubik Medium, the app's font: Latin and Cyrillic.
  rubik(
    assetKey: 'assets/fonts/Rubik-Medium.ttf',
    fileName: 'Rubik-Medium.v1.ttf',
    flutterFamily: 'Rubik',
    flutterWeight: FontWeight.w500,
    coverage: StampFontCoverage.rubik,
  ),

  /// Yusei Magic (6 MB), the stamp font of older versions, kept behind the
  /// "legacy font" preference: Latin, Japanese and the Chinese of dates.
  yuseiMagic(
    assetKey: 'assets/fonts/YuseiMagic-Regular.ttf',
    fileName: 'YuseiMagic-Regular.v1.ttf',
    flutterFamily: 'Magic',
    flutterWeight: FontWeight.w400,
    coverage: StampFontCoverage.yuseiMagic,
  ),

  /// Noto Sans SC Medium (8 MB): Chinese, and whatever else the others
  /// cannot draw (Japanese, Greek, Vietnamese).
  notoSansSc(
    assetKey: 'assets/fonts/NotoSansSC-Medium.otf',
    fileName: 'NotoSansSC-Medium.v1.otf',
    flutterFamily: 'NotoSansSC',
    flutterWeight: FontWeight.w500,
    coverage: StampFontCoverage.notoSansSc,
  );

  const StampFont({
    required this.assetKey,
    required this.fileName,
    required this.flutterFamily,
    required this.flutterWeight,
    required this._coverage,
  });

  /// The bundled asset copied out for ffmpeg (it cannot read assets).
  final String assetKey;

  /// The copy's name in `AppPaths.fontsDir`. VERSIONED: an existing copy is
  /// never refreshed, so bump the version whenever the asset changes (a test
  /// pins each asset's checksum to it). Only `[A-Za-z0-9._-]`, since the
  /// path goes into a filter string.
  final String fileName;

  /// The Flutter font family of the same file (`pubspec.yaml`).
  final String flutterFamily;

  /// The weight the file has in [flutterFamily].
  final FontWeight flutterWeight;

  /// The code points the font draws: sorted `start, end` pairs.
  final List<int> _coverage;

  /// Where ffmpeg reads the copy from.
  String pathIn(AppPaths paths) => '${paths.fontsDir}/$fileName';

  /// Whether the font has a glyph for [codePoint].
  bool draws(int codePoint) {
    int low = 0;
    int high = _coverage.length ~/ 2 - 1;
    while (low <= high) {
      final int middle = (low + high) ~/ 2;
      if (codePoint < _coverage[2 * middle]) {
        high = middle - 1;
      } else if (codePoint > _coverage[2 * middle + 1]) {
        low = middle + 1;
      } else {
        return true;
      }
    }
    return false;
  }

  /// How many characters of [text] the font cannot draw. Control
  /// characters (the place file's CR) draw nothing in any font.
  int missingIn(String text) {
    int missing = 0;
    for (final int codePoint in text.runes) {
      if (codePoint >= 0x20 && !draws(codePoint)) missing++;
    }
    return missing;
  }
}
