/// A clip's tags, as written into its `keywords` metadata (the MP4 `keyw`
/// atom): `keywords=bread,sour dough,trip`. The tag is part of the clip
/// format contract: it travels with the file, so a tagged clip keeps its
/// tags after a reinstall or on another phone, and galleries that read
/// keywords show them.
///
/// The value is a comma-separated list, so a tag never contains a comma
/// (`TagName` refuses one). The order and the casing are whatever the
/// caller gives; `TagName.normalize` makes them canonical (sorted by fold
/// key, one casing per tag) before a write, so one set of tags always
/// gives one `keywords` value.
///
/// A clip without tags has no `keywords` tag at all (an empty
/// `-metadata keywords=` deletes it).
abstract final class KeywordsTag {
  /// The separator between tags.
  static const String separator = ',';

  /// The `keywords` value for [tags], in the order given; `''` for none
  /// (which deletes the tag). Throws an [ArgumentError] for a tag with a
  /// comma, which the list could not hold.
  static String format(Iterable<String> tags) {
    for (final String tag in tags) {
      if (tag.contains(separator)) {
        throw ArgumentError.value(tag, 'tags', 'contains a comma');
      }
    }
    return tags.join(separator);
  }

  /// The tags in a `keywords` value: each part trimmed, empties dropped,
  /// repeats (exact) kept once, in the file's order. An absent tag reads as
  /// no tags. Never throws.
  static List<String> parse(String? keywords) {
    if (keywords == null) return const <String>[];
    final List<String> tags = <String>[];
    for (final String part in keywords.split(separator)) {
      final String tag = part.trim();
      if (tag.isNotEmpty && !tags.contains(tag)) tags.add(tag);
    }
    return tags;
  }
}
