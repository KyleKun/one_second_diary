import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';

/// Which clips a tag filter keeps: those with any of [anyOf] (none listed:
/// every clip), minus those with one of [noneOf]; with [untaggedOnly], only
/// clips without a tag. Tags are compared by [TagName.fold].
///
/// The Diary's filter uses [anyOf] and [untaggedOnly]; a movie uses
/// [anyOf] ("only clips tagged…") and [noneOf] ("leave out clips tagged…").
final class TagFilter extends Equatable {
  TagFilter({
    Set<String> anyOf = const <String>{},
    Set<String> noneOf = const <String>{},
    this.untaggedOnly = false,
  }) : anyOf = Set<String>.unmodifiable(anyOf),
       noneOf = Set<String>.unmodifiable(noneOf),
       _anyKeys = <String>{for (final String tag in anyOf) TagName.fold(tag)},
       _noneKeys = <String>{for (final String tag in noneOf) TagName.fold(tag)};

  /// Keeps every clip.
  static final TagFilter none = TagFilter();

  /// The tags a clip must have one of (display names, as chosen).
  final Set<String> anyOf;

  /// The tags a clip must have none of.
  final Set<String> noneOf;

  final bool untaggedOnly;

  final Set<String> _anyKeys;
  final Set<String> _noneKeys;

  /// Whether this filter keeps every clip.
  bool get isEmpty => anyOf.isEmpty && noneOf.isEmpty && !untaggedOnly;

  bool get isNotEmpty => !isEmpty;

  /// Whether a clip with [tags] is kept.
  bool matches(List<String> tags) {
    if (untaggedOnly && tags.isNotEmpty) return false;
    if (_anyKeys.isEmpty && _noneKeys.isEmpty) return true;
    bool any = _anyKeys.isEmpty;
    for (final String tag in tags) {
      final String key = TagName.fold(tag);
      if (_noneKeys.contains(key)) return false;
      if (_anyKeys.contains(key)) any = true;
    }
    return any;
  }

  /// Whether [tag] is one of [anyOf].
  bool includes(String tag) => _anyKeys.contains(TagName.fold(tag));

  /// Whether [tag] is one of [noneOf].
  bool excludes(String tag) => _noneKeys.contains(TagName.fold(tag));

  /// This filter with [tag] added to, or removed from, [anyOf].
  TagFilter toggleAny(String tag) => TagFilter(
    anyOf: _toggled(anyOf, tag),
    noneOf: noneOf,
    untaggedOnly: untaggedOnly,
  );

  /// This filter with [tag] added to, or removed from, [noneOf].
  TagFilter toggleNone(String tag) => TagFilter(
    anyOf: anyOf,
    noneOf: _toggled(noneOf, tag),
    untaggedOnly: untaggedOnly,
  );

  TagFilter withUntaggedOnly({required bool untaggedOnly}) =>
      TagFilter(anyOf: anyOf, noneOf: noneOf, untaggedOnly: untaggedOnly);

  static Set<String> _toggled(Set<String> tags, String tag) {
    final String key = TagName.fold(tag);
    final Set<String> next = <String>{
      for (final String other in tags)
        if (TagName.fold(other) != key) other,
    };
    if (next.length == tags.length) next.add(tag);
    return next;
  }

  @override
  List<Object?> get props => <Object?>[_anyKeys, _noneKeys, untaggedOnly];
}
