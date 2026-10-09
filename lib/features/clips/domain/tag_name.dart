import 'package:one_second_diary/features/profiles/domain/latin_composition.dart';

/// Why a typed tag can't be one.
enum TagNameError {
  /// Nothing left after trimming.
  empty,

  /// Longer than [TagName.maxLength] once cleaned.
  tooLong,

  /// Holds a comma, the separator of the `keywords` tag.
  comma,

  /// Holds a control or line-break character.
  invalidCharacters,

  /// The clip already has this tag (compared by [TagName.fold]).
  duplicate,

  /// The clip already has [TagName.maxPerClip] tags.
  tooMany,
}

/// The rules of a tag name, and the one form tags are compared in.
///
/// A tag is free text: trimmed, with runs of whitespace collapsed to one
/// space and format characters removed ([clean]), 1 to [maxLength]
/// characters, no comma (`KeywordsTag` separates tags with it) and no
/// control characters. Two tags are the same when their [fold] is
/// (accents composed, lower-cased), and the casing typed first is the one
/// kept. A clip holds at most [maxPerClip] tags.
abstract final class TagName {
  static const int maxLength = 30;
  static const int maxPerClip = 20;

  /// Why [raw] (as typed) can't be added to a clip that already has
  /// [existing], or null when it can.
  static TagNameError? validate(
    String raw, {
    Iterable<String> existing = const <String>[],
  }) {
    if (_controls.hasMatch(raw)) return TagNameError.invalidCharacters;
    if (raw.contains(',')) return TagNameError.comma;
    final String cleaned = clean(raw);
    if (cleaned.isEmpty) return TagNameError.empty;
    if (cleaned.length > maxLength) return TagNameError.tooLong;
    final String key = fold(cleaned);
    int count = 0;
    for (final String tag in existing) {
      if (fold(tag) == key) return TagNameError.duplicate;
      count++;
    }
    if (count >= maxPerClip) return TagNameError.tooMany;
    return null;
  }

  /// [raw] as a tag is stored: format characters removed, accents
  /// composed, whitespace collapsed and trimmed. May be empty.
  static String clean(String raw) => LatinComposition.compose(
    raw.replaceAll(_format, ''),
  ).replaceAll(_whitespace, ' ').trim();

  /// The form two tags are compared in: [clean]ed and lower-cased.
  static String fold(String tag) => clean(tag).toLowerCase();

  /// [tags] as a clip stores them: each [clean]ed, empties and anything
  /// [validate] refuses dropped, one per [fold] (the first casing kept),
  /// sorted by fold so one set of tags always gives one `keywords` value.
  /// Never more than [maxPerClip].
  static List<String> normalize(Iterable<String> tags) {
    final Map<String, String> byKey = <String, String>{};
    for (final String raw in tags) {
      if (_controls.hasMatch(raw) || raw.contains(',')) continue;
      final String cleaned = clean(raw);
      if (cleaned.isEmpty || cleaned.length > maxLength) continue;
      byKey.putIfAbsent(fold(cleaned), () => cleaned);
      if (byKey.length == maxPerClip) break;
    }
    final List<String> keys = byKey.keys.toList()..sort();
    return List<String>.unmodifiable(<String>[
      for (final String key in keys) byKey[key]!,
    ]);
  }

  /// Whether [a] and [b] are the same tag.
  static bool same(String a, String b) => fold(a) == fold(b);

  static final RegExp _format = RegExp(r'\p{Cf}', unicode: true);
  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _controls = RegExp(
    r'[\p{Cc}\p{Zl}\p{Zp}]',
    unicode: true,
  );
}
