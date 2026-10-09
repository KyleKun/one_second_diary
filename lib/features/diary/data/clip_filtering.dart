import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/diary/domain/clip_filter.dart';

/// Applies a [ClipFilter] to a snapshot, from memory: the index's tags and,
/// for a text search, each clip's subtitle and place from the metadata
/// cache (two hash lookups a clip). One pass over the clips; the result is
/// a `ClipIndex` every Diary query works on. The caller keeps it while
/// neither the snapshot nor the filter changes.
///
/// A plain class (not final), so tests can fake it.
class ClipFiltering {
  ClipFiltering({required this._metadata});

  final ClipMetadataCache _metadata;

  /// The clips of [index] that [filter] keeps: [index] itself for an empty
  /// filter.
  ClipIndex of(ClipIndex index, ClipFilter filter) {
    if (filter.isEmpty) return index;
    final ClipFilterMatcher matches = filter.matcher;
    final bool readsMeta = filter.hasQuery;
    return index.where(
      (ClipRef clip) => matches(
        tags: index.tagsOf(clip),
        meta: readsMeta ? _metaOf(index, clip) : null,
      ),
    );
  }

  ClipMeta? _metaOf(ClipIndex index, ClipRef clip) {
    final FileStamp? stamp = index.stampOf(clip);
    if (stamp == null) return null;
    return _metadata.lookup(relPath: clip.relPath, stamp: stamp);
  }
}
