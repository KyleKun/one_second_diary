import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/diary/domain/clip_caption.dart';

/// Reads a clip's [ClipCaption] from the metadata cache, in memory: two
/// hash lookups, so a card or a caption row can ask for it while it builds.
///
/// The cache answers for the clip's version in the index only, so a clip
/// whose subtitles were just rewritten never shows the old text. A clip the
/// backfill has not described yet has none.
///
/// A plain class (not final), so tests can fake it.
class ClipCaptions {
  ClipCaptions({required this._clips, required this._metadata});

  final ClipRepository _clips;
  final ClipMetadataCache _metadata;

  /// The caption of [clip]; [ClipCaption.none] when nothing is known.
  ClipCaption of(ClipRef clip) {
    final FileStamp? stamp = _clips.snapshotOf(clip.profile)?.stampOf(clip);
    if (stamp == null) return ClipCaption.none;
    final ClipMeta? meta = _metadata.lookup(
      relPath: clip.relPath,
      stamp: stamp,
    );
    return ClipCaption(
      subtitle: _textOf(meta?.subtitleText),
      location: _textOf(meta?.locationText),
    );
  }

  static String? _textOf(String? text) {
    final String? trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
