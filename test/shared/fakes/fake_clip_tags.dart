import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/data/clip_tags.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import 'fake_clip_repository.dart';

/// A [ClipTags] over a [FakeClipRepository]: [tagsOf] reads the
/// repository's snapshots, [setTags] records the write in [writes] and
/// applies it through `tagsKnown` at once (as the real one tells the
/// library first), or throws [failure] when the test scripted one, leaving
/// the library as it was. [vocabulary] is the [suggestions] the test scripts.
class FakeClipTags extends Fake implements ClipTags {
  FakeClipTags(this.clips, {this.suggestions = const <TagCount>[]});

  final FakeClipRepository clips;

  /// What [setTags] was asked, in order.
  final List<({ClipRef clip, List<String> tags})> writes =
      <({ClipRef clip, List<String> tags})>[];

  /// The suggestions of the tags sheet ([vocabulary]).
  final List<TagCount> suggestions;

  /// When set, the next [setTags] throws it instead of writing.
  Object? failure;

  @override
  List<String> tagsOf(ClipRef clip) =>
      clips.snapshotOf(clip.profile)?.tagsOf(clip) ?? const <String>[];

  @override
  List<TagCount> vocabulary({ProfileKey? profile}) => suggestions;

  @override
  Future<void> setTags(ClipRef clip, List<String> tags) async {
    final List<String> normalized = TagName.normalize(tags);
    writes.add((clip: clip, tags: normalized));
    final Object? failure = this.failure;
    if (failure != null) {
      this.failure = null;
      throw failure;
    }
    clips.tagsKnown(clip.relPath, normalized);
  }
}
