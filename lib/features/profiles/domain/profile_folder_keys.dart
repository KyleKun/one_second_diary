import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Derives the immutable folder key of a NEW profile from its display name.
///
/// The key is the folder under `Profiles/`, the gallery album and the suffix
/// of `orientation_<key>`: ASCII letters, digits, space, `_` and `-` only.
/// - accented Latin letters fold to their base (José -> `Jose`);
/// - other characters are dropped and runs of spaces collapse, so `/` and `.`
///   can never make a path;
/// - nothing left (Дача, 🎈) gives `profile_<n>`, the first free n;
/// - a taken key gets the first free `_<n>` suffix, from 2.
///
/// A key reading `default` in any case counts as taken.
abstract final class ProfileFolderKeys {
  /// The key for [displayName]. [isTaken] says whether a candidate is
  /// already used (by a registered profile, a folder on disk or a stored
  /// orientation); compare case-insensitively there, because Android's
  /// shared storage is case-insensitive.
  static ProfileKey forDisplayName(
    String displayName, {
    required bool Function(String candidate) isTaken,
  }) {
    bool free(String candidate) =>
        candidate.toLowerCase() != 'default' && !isTaken(candidate);

    final String base = _sanitise(displayName);
    if (base.isEmpty) return ProfileKey(_firstFree('profile_', 1, free));
    if (free(base)) return ProfileKey(base);
    return ProfileKey(_firstFree('${base}_', 2, free));
  }

  static String _sanitise(String displayName) {
    final StringBuffer key = StringBuffer();
    for (final int rune in displayName.runes) {
      final String char = String.fromCharCode(rune);
      final String folded = _latinFolds[char] ?? char;
      if (_legacyRule.hasMatch(folded)) {
        key.write(folded);
      } else if (char.trim().isEmpty) {
        key.write(' ');
      }
    }
    return key.toString().replaceAll(_spaces, ' ').trim();
  }

  static String _firstFree(
    String prefix,
    int from,
    bool Function(String candidate) free,
  ) {
    int n = from;
    while (!free('$prefix$n')) {
      n++;
    }
    return '$prefix$n';
  }

  static final RegExp _legacyRule = RegExp(r'^[A-Za-z0-9 _-]+$');
  static final RegExp _spaces = RegExp(' {2,}');

  /// Base letters of the precomposed Latin letters (Latin-1 Supplement and
  /// Latin Extended-A), grouped by replacement.
  static const Map<String, String> _latinGroups = <String, String>{
    'A': 'ÀÁÂÃÄÅĀĂĄ',
    'a': 'àáâãäåāăą',
    'AE': 'Æ',
    'ae': 'æ',
    'C': 'ÇĆĈĊČ',
    'c': 'çćĉċč',
    'D': 'ĎĐÐ',
    'd': 'ďđð',
    'E': 'ÈÉÊËĒĔĖĘĚ',
    'e': 'èéêëēĕėęě',
    'G': 'ĜĞĠĢ',
    'g': 'ĝğġģ',
    'H': 'ĤĦ',
    'h': 'ĥħ',
    'I': 'ÌÍÎÏĨĪĬĮİ',
    'i': 'ìíîïĩīĭįı',
    'IJ': 'Ĳ',
    'ij': 'ĳ',
    'J': 'Ĵ',
    'j': 'ĵ',
    'K': 'Ķ',
    'k': 'ķĸ',
    'L': 'ĹĻĽĿŁ',
    'l': 'ĺļľŀł',
    'N': 'ÑŃŅŇŊ',
    'n': 'ñńņňŉŋ',
    'O': 'ÒÓÔÕÖØŌŎŐ',
    'o': 'òóôõöøōŏő',
    'OE': 'Œ',
    'oe': 'œ',
    'R': 'ŔŖŘ',
    'r': 'ŕŗř',
    'S': 'ŚŜŞŠ',
    's': 'śŝşšſ',
    'ss': 'ß',
    'T': 'ŢŤŦ',
    't': 'ţťŧ',
    'TH': 'Þ',
    'th': 'þ',
    'U': 'ÙÚÛÜŨŪŬŮŰŲ',
    'u': 'ùúûüũūŭůűų',
    'W': 'Ŵ',
    'w': 'ŵ',
    'Y': 'ÝŶŸ',
    'y': 'ýÿŷ',
    'Z': 'ŹŻŽ',
    'z': 'źżž',
  };

  static final Map<String, String> _latinFolds = <String, String>{
    for (final MapEntry<String, String> group in _latinGroups.entries)
      for (final String letter in group.value.split('')) letter: group.key,
  };
}
