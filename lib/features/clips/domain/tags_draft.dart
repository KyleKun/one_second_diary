import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';

/// What the tags sheet edits: the clip's tags as it opened ([initial]) and
/// as they are now ([tags]), in the order they were added. Pure, so the
/// sheet's rules are tested without widgets.
///
/// [add] takes a tag as typed and answers with the draft after it and why
/// it was refused, if it was (`TagName.validate`); [remove] drops one by
/// `TagName.fold`. [isDirty] says whether Save has anything to write:
/// the same set in another order or casing is not a change.
final class TagsDraft extends Equatable {
  const TagsDraft._({required this.initial, required this.tags});

  /// A draft opened on [tags] (kept as given; `TagName.normalize` sorts
  /// them for the file).
  factory TagsDraft.of(List<String> tags) {
    final List<String> kept = List<String>.unmodifiable(tags);
    return TagsDraft._(initial: kept, tags: kept);
  }

  /// The tags the sheet opened on.
  final List<String> initial;

  /// The tags now, in the order they were added.
  final List<String> tags;

  /// Whether the clip has no tags now.
  bool get isEmpty => tags.isEmpty;

  /// Whether Save would change the clip's tags.
  bool get isDirty {
    final List<String> was = TagName.normalize(initial);
    final List<String> now = TagName.normalize(tags);
    if (was.length != now.length) return true;
    for (int i = 0; i < was.length; i++) {
      if (was[i] != now[i]) return true;
    }
    return false;
  }

  /// The tags as the clip stores them (`TagName.normalize`): what Save
  /// writes.
  List<String> get normalized => TagName.normalize(tags);

  /// Adds [raw] as typed: the draft with it cleaned, and null; or this
  /// draft and why it can't be added.
  (TagsDraft, TagNameError?) add(String raw) {
    final TagNameError? error = TagName.validate(raw, existing: tags);
    if (error != null) return (this, error);
    return (
      TagsDraft._(
        initial: initial,
        tags: List<String>.unmodifiable(<String>[...tags, TagName.clean(raw)]),
      ),
      null,
    );
  }

  /// Drops [tag] (compared by `TagName.fold`); this draft when it has no
  /// such tag.
  TagsDraft remove(String tag) {
    final String key = TagName.fold(tag);
    final List<String> kept = <String>[
      for (final String other in tags)
        if (TagName.fold(other) != key) other,
    ];
    if (kept.length == tags.length) return this;
    return TagsDraft._(initial: initial, tags: List<String>.unmodifiable(kept));
  }

  /// Whether the clip has [tag] now (compared by `TagName.fold`).
  bool has(String tag) {
    final String key = TagName.fold(tag);
    return tags.any((String other) => TagName.fold(other) == key);
  }

  @override
  List<Object?> get props => <Object?>[initial, tags];
}
