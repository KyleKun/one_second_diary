/// Canonical composition (Unicode NFC) of the accented Latin letters in
/// Latin-1 Supplement and Latin Extended-A: a base letter plus one combining
/// mark becomes the precomposed letter (`Jose` + U+0301 reads as `José`).
///
/// A pasted name may be decomposed (NFD, e.g. from a macOS file name) and look
/// identical on screen. Dart has no normalisation API, so this covers the
/// letters `ProfileFolderKeys` also folds; any other sequence is left as is.
abstract final class LatinComposition {
  /// [text] with every composable base letter + combining mark pair
  /// replaced by its precomposed letter.
  static String compose(String text) => text.replaceAllMapped(
    _baseAndMark,
    (Match pair) => _composed[pair[0]!] ?? pair[0]!,
  );

  static final RegExp _baseAndMark = RegExp('[A-Za-z][̀-ͯ]');

  /// Per combining mark, pairs of (base letter, precomposed letter).
  static const Map<int, String> _pairsByMark = <int, String>{
    0x0300: 'AÀEÈIÌOÒUÙaàeèiìoòuù', // grave accent
    0x0301: 'AÁEÉIÍOÓUÚYÝaáeéiíoóuúyýCĆcćLĹlĺNŃnńRŔrŕSŚsśZŹzź', // acute
    0x0302: 'AÂEÊIÎOÔUÛaâeêiîoôuûCĈcĉGĜgĝHĤhĥJĴjĵSŜsŝWŴwŵYŶyŷ', // circumflex
    0x0303: 'AÃNÑOÕaãnñoõIĨiĩUŨuũ', // tilde
    0x0304: 'AĀaāEĒeēIĪiīOŌoōUŪuū', // macron
    0x0306: 'AĂaăEĔeĕGĞgğIĬiĭOŎoŏUŬuŭ', // breve
    0x0307: 'CĊcċEĖeėGĠgġIİZŻzż', // dot above
    0x0308: 'AÄEËIÏOÖUÜaäeëiïoöuüyÿYŸ', // diaeresis
    0x030A: 'AÅaåUŮuů', // ring above
    0x030B: 'OŐoőUŰuű', // double acute accent
    0x030C: 'CČcčDĎdďEĚeěLĽlľNŇnňRŘrřSŠsšTŤtťZŽzž', // caron
    0x0327: 'CÇcçGĢgģKĶkķLĻlļNŅnņRŖrŗSŞsşTŢtţ', // cedilla
    0x0328: 'AĄaąEĘeęIĮiįUŲuų', // ogonek
  };

  static final Map<String, String> _composed = <String, String>{
    for (final MapEntry<int, String>(key: int mark, value: String pairs)
        in _pairsByMark.entries)
      for (int i = 0; i < pairs.length; i += 2)
        '${pairs[i]}${String.fromCharCode(mark)}': pairs[i + 1],
  };
}
