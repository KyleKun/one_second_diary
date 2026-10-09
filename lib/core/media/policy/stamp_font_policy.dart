import 'package:one_second_diary/core/media/policy/stamp_font.dart';

/// Which font draws a clip's stamps.
abstract final class StampFontPolicy {
  /// The one font for [texts] (the date, and the place when there is one):
  /// Rubik, then Noto Sans SC for what Rubik cannot draw (Chinese). With
  /// the "legacy font" preference ([legacy]), Yusei Magic comes first, as
  /// older versions burned it, then the same two.
  ///
  /// The first font that draws every character wins; when none does (a
  /// Czech date with a Chinese place), the one missing the fewest.
  static StampFont forTexts(Iterable<String> texts, {required bool legacy}) {
    final String text = texts.join();
    StampFont best = StampFont.notoSansSc;
    int? fewest;
    for (final StampFont font in legacy ? _legacyOrder : _order) {
      final int missing = font.missingIn(text);
      if (missing == 0) return font;
      if (fewest == null || missing < fewest) {
        best = font;
        fewest = missing;
      }
    }
    return best;
  }

  static const List<StampFont> _order = <StampFont>[
    StampFont.rubik,
    StampFont.notoSansSc,
  ];

  static const List<StampFont> _legacyOrder = <StampFont>[
    StampFont.yuseiMagic,
    ..._order,
  ];
}
