import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';

/// A real [ClipMetadataCache] that also records, synchronously, which clips
/// its flushes have saved ([saved]). The sidecar itself is written in a
/// background isolate, so a test could otherwise only tell that a flush did
/// NOT happen by waiting on the wall clock.
class SavingClipMetadataCache extends ClipMetadataCache {
  SavingClipMetadataCache({required super.paths, required super.logger});

  final Set<String> _unsaved = <String>{};

  /// The relPaths saved by the flushes so far.
  final Set<String> saved = <String>{};

  @override
  void put({
    required String relPath,
    required FileStamp stamp,
    required ClipMeta meta,
  }) {
    super.put(relPath: relPath, stamp: stamp, meta: meta);
    _unsaved.add(relPath);
  }

  @override
  Future<void> flush() {
    saved.addAll(_unsaved);
    _unsaved.clear();
    return super.flush();
  }
}
