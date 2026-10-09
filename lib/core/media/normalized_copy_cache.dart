import 'dart:convert';
import 'dart:io';

import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/platform/clock.dart';

/// The cache's cap in bytes, read afresh at each trim: in the app
/// `StorageBudget.normalizedCacheCap` of the free space (10 %, between 512
/// MiB and 8 GiB).
typedef CacheCapBytes = Future<int> Function();

/// The normalised copies of clips that cannot join a movie as they are
/// (`MoviePlan.needsNormalising`), kept between movies in
/// `AppPaths.normalizedDir` (the purgeable cache, never DCIM).
///
/// A copy is reused while the cache holds it and the clip is unchanged: an
/// entry is keyed by the clip's path relative to `AppPaths.videos` plus its
/// size and modification time, and the format it was normalised into
/// ([keyFor]), so an edited or replaced clip is never joined from a stale
/// copy, nor a copy of one format into a movie of another.
///
/// Least recently used copies go first once the folder is over its cap
/// ([trim]). Recency is the copy's modification time, set from the injected
/// [Clock] when it is stored or found, so no index file can go out of sync
/// with the folder.
///
/// The cap follows the free space ([CacheCapBytes], read at each trim), so
/// a movie with more such clips than fit keeps only the most recently
/// joined copies, and the next such movie re-encodes the others. The folder
/// is OS-purgeable, so the system may still drop copies under storage
/// pressure.
final class NormalizedCopyCache {
  NormalizedCopyCache({
    required this._directory,
    required this._capBytes,
    required this._clock,
  });

  final String _directory;
  final CacheCapBytes _capBytes;
  final Clock _clock;

  static const String _extension = '.mp4';

  /// The cache key of a clip at [relPath] (relative to `AppPaths.videos`,
  /// never absolute: the iOS container path changes on reinstall) with
  /// [sizeBytes] and [modified], normalised into [format] (its canonical
  /// string and its orientation); with [keyframes], a copy
  /// that carries the cut keyframes (`-kf`), so a copy
  /// made before them is never reused for one. Only `[A-Za-z0-9._-]`, so
  /// it is a plain file name.
  static String keyFor({
    required String relPath,
    required int sizeBytes,
    required DateTime modified,
    required ClipFormat format,
    bool keyframes = false,
  }) =>
      '${_fnv1a32(utf8.encode(relPath)).toRadixString(16).padLeft(8, '0')}'
      '-$sizeBytes-${modified.millisecondsSinceEpoch}'
      '-$format-${format.orientation.name}'
      '${keyframes ? '-kf' : ''}';

  /// The stored copy for [key], marked as just used; null when there is none.
  Future<String?> lookup(String key) async {
    final File file = File(_pathOf(key));
    try {
      await file.setLastModified(_clock.now());
      return file.path;
    } on FileSystemException {
      return null;
    }
  }

  /// Moves the finished copy at [file] into the cache under [key], marked as
  /// just used, and returns its new path.
  Future<String> put({required String key, required String file}) async {
    await Directory(_directory).create(recursive: true);
    final String path = _pathOf(key);
    await _move(File(file), path);
    await File(path).setLastModified(_clock.now());
    return path;
  }

  /// Deletes the least recently used copies until the cache holds at most
  /// its cap, read afresh now. Call it when no movie is joining copies.
  Future<void> trim() async {
    final int capBytes = await _capBytes();
    final List<(File, FileStat)> copies = <(File, FileStat)>[];
    try {
      await for (final FileSystemEntity entity in Directory(
        _directory,
      ).list()) {
        if (entity is File && entity.path.endsWith(_extension)) {
          copies.add((entity, await entity.stat()));
        }
      }
    } on PathNotFoundException {
      return;
    }
    int total = copies.fold(
      0,
      (int sum, (File, FileStat) c) => sum + c.$2.size,
    );
    copies.sort(
      ((File, FileStat) a, (File, FileStat) b) =>
          a.$2.modified.compareTo(b.$2.modified),
    );
    for (final (File file, FileStat stat) in copies) {
      if (total <= capBytes) break;
      await file.delete();
      total -= stat.size;
    }
  }

  String _pathOf(String key) => '$_directory/$key$_extension';

  /// A rename (scratch and cache share a volume on devices), or a copy
  /// through a temp name when they don't, so a copy cut short never sits
  /// under a key.
  static Future<void> _move(File from, String to) async {
    try {
      await from.rename(to);
    } on FileSystemException {
      final String partial = '$to.part';
      await from.copy(partial);
      await File(partial).rename(to);
      await from.delete();
    }
  }

  /// FNV-1a, 32 bits: turns any relative path into a short file-name part.
  /// With the size and time beside it, two clips never share a key.
  static int _fnv1a32(List<int> bytes) {
    int hash = 0x811c9dc5;
    for (final int byte in bytes) {
      hash = ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
