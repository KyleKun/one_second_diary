import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';

/// What a clip matches [ClipFilter] with: its [tags] (the index's) and its
/// cached facts ([meta], null until the backfill has read it).
typedef ClipFilterMatcher =
    bool Function({required List<String> tags, required ClipMeta? meta});

/// The Diary's filter: a [TagFilter] (any of the chosen tags, or "Without
/// tags") and a free-text [query] searched in a clip's tags, subtitle and
/// place. A clip is kept when both agree.
///
/// Text is compared by [TagName.fold] (accents composed, lower-cased,
/// whitespace collapsed), so "café" finds "Café". A clip whose facts are
/// not known yet ([ClipMeta] null) matches a query through its tags only.
///
/// Session-only: the Diary never stores it, and a profile switch clears it.
final class ClipFilter extends Equatable {
  /// A filter of [tags] and [query] (as typed; the search ignores case).
  const ClipFilter({this._tags, this.query = ''});

  /// Keeps every clip.
  const ClipFilter.none() : this();

  final TagFilter? _tags;

  /// The tag side of the filter ([TagFilter.none] when there is none).
  TagFilter get tags => _tags ?? TagFilter.none;

  /// The search text, as typed.
  final String query;

  /// [query] as it is compared: folded like a tag; empty when the query is
  /// blank.
  String get needle => TagName.fold(query);

  bool get hasQuery => needle.isNotEmpty;

  /// Whether this filter keeps every clip.
  bool get isEmpty => tags.isEmpty && !hasQuery;

  bool get isNotEmpty => !isEmpty;

  /// Whether a clip with [tags] and [meta] is kept.
  bool matches({required List<String> tags, required ClipMeta? meta}) =>
      _matches(tags, meta, needle);

  /// [matches] with the query folded once, for a pass over every clip.
  ClipFilterMatcher get matcher {
    final String needle = this.needle;
    return ({required List<String> tags, required ClipMeta? meta}) =>
        _matches(tags, meta, needle);
  }

  bool _matches(List<String> tags, ClipMeta? meta, String needle) {
    if (!this.tags.matches(tags)) return false;
    if (needle.isEmpty) return true;
    for (final String tag in tags) {
      if (TagName.fold(tag).contains(needle)) return true;
    }
    return _contains(meta?.subtitleText, needle) ||
        _contains(meta?.locationText, needle);
  }

  static bool _contains(String? text, String needle) =>
      text != null && text.isNotEmpty && TagName.fold(text).contains(needle);

  ClipFilter withTags(TagFilter tags) => ClipFilter(tags: tags, query: query);

  ClipFilter withQuery(String query) => ClipFilter(tags: tags, query: query);

  @override
  List<Object?> get props => <Object?>[tags, query];
}
