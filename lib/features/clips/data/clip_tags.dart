import 'dart:async';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_rewriter.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Sets a saved clip's tags and renames or removes a tag across clips.
///
/// A clip's tags are in its file (`KeywordsTag`); the library
/// (`ClipIndex.tagsOf`) and the metadata cache only mirror them. [setTags]
/// tells the library first, so every screen shows the change at once, then
/// rewrites the file through [ClipRewriter]. When the rewrite fails the
/// library shows the clip's old tags again. Not final so tests can fake it.
class ClipTags {
  ClipTags({
    required this._engine,
    required MediaPublisher publisher,
    required ClipRepository repository,
    required ClipMetadataCache metadata,
    required ThumbnailRepository thumbnails,
    required AppPaths paths,
    required this._logger,
  }) : _repository = repository,
       _rewriter = ClipRewriter(
         publisher: publisher,
         repository: repository,
         metadata: metadata,
         thumbnails: thumbnails,
         paths: paths,
       );

  final MediaEngine _engine;
  final ClipRepository _repository;
  final ClipRewriter _rewriter;
  final AppLogger _logger;

  static const String _tag = 'TAGS';

  /// The end of the last write asked for each clip, by relPath: a clip's
  /// writes run one after the other, so two edits never rewrite one file
  /// at once.
  final Map<String, Completer<void>> _writes = <String, Completer<void>>{};

  /// The tags of [clip], as the library knows them.
  List<String> tagsOf(ClipRef clip) =>
      _repository.snapshotOf(clip.profile)?.tagsOf(clip) ?? const <String>[];

  /// Every tag of every loaded profile with its clip count, most used
  /// first: the suggestions of the tags sheet and the list of Settings.
  /// Tags are one per `TagName.fold`, named as [profile]'s clips name them
  /// first, else as the other profiles do.
  List<TagCount> vocabulary({ProfileKey? profile}) {
    final Map<String, String> names = <String, String>{};
    final Map<String, int> counts = <String, int>{};
    void add(Iterable<TagCount> tags) {
      for (final TagCount tag in tags) {
        final String key = TagName.fold(tag.name);
        names.putIfAbsent(key, () => tag.name);
        counts[key] = (counts[key] ?? 0) + tag.count;
      }
    }

    final Map<ProfileKey, ClipIndex> snapshots = _repository.snapshots;
    if (snapshots[profile] case final ClipIndex own) add(own.tagCounts);
    for (final MapEntry<ProfileKey, ClipIndex> entry in snapshots.entries) {
      if (entry.key != profile) add(entry.value.tagCounts);
    }
    final List<TagCount> result =
        <TagCount>[
          for (final MapEntry<String, int> entry in counts.entries)
            TagCount(name: names[entry.key]!, count: entry.value),
        ]..sort((TagCount a, TagCount b) {
          final int byCount = b.count.compareTo(a.count);
          return byCount != 0
              ? byCount
              : TagName.fold(a.name).compareTo(TagName.fold(b.name));
        });
    return result;
  }

  /// Gives [clip] exactly [tags] (normalised by `TagName`; empty removes
  /// them all); nothing to do when it already has them.
  ///
  /// Throws `VideoProcessingException` when the remux failed and
  /// [MediaStoreException] when the gallery refused the new file; the clip
  /// is then as it was.
  Future<void> setTags(ClipRef clip, List<String> tags) async {
    final Completer<void>? previous = _writes[clip.relPath];
    final Completer<void> done = Completer<void>();
    _writes[clip.relPath] = done;
    try {
      // Never fails: a failed write is told to its own caller only.
      await previous?.future;
      await _set(clip, TagName.normalize(tags));
    } finally {
      if (identical(_writes[clip.relPath], done)) {
        _writes.remove(clip.relPath);
      }
      done.complete();
    }
  }

  Future<void> _set(ClipRef clip, List<String> tags) async {
    final List<String> was = tagsOf(clip);
    if (_same(was, tags)) return;
    _repository.tagsKnown(clip.relPath, tags);
    try {
      await _rewriter.replaceWith(
        clip,
        remux: (String path) => _engine.remuxTags(clipPath: path, tags: tags),
        patchMeta: (ClipMeta meta) => meta.withTags(tags),
      );
      _logger.info(_tag, 'Tagged ${clip.relPath}: ${tags.join(', ')}');
    } on Object catch (error, stackTrace) {
      _repository.tagsKnown(clip.relPath, was);
      _logger.error(
        _tag,
        'Could not write the tags of ${clip.relPath}',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
