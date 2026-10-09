import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_meta_sidecar.dart';
import 'package:one_second_diary/features/clips/data/stamped_clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';

/// Cached facts about every clip ([ClipMeta]), so no screen and no movie
/// runs ffmpeg to learn a clip's duration, subtitles or location.
///
/// - Persisted as JSON in `AppPaths.supportIndexDir`/[fileName], keyed by
///   the clip's path relative to the videos folder (never absolute: the iOS
///   container path changes on reinstall).
/// - Each entry carries the [FileStamp] of the file it describes, and
///   [lookup] serves it only while the clip still has that stamp, so a clip
///   rewritten in place is never described by stale facts.
/// - The save flows write their clip's facts through ([write]); clips
///   without facts are filled once by the `ClipMetadataBackfill`, which
///   [put]s many entries and [flush]es now and then.
/// - Reading and writing the file (and the JSON work) run in a background
///   isolate; flushes are serialised, so the newest state is always the one
///   left on disk.
/// - Every way a clip's facts arrive (a save, the backfill, a privacy, tags or
///   subtitle edit) is a [put], so [privacyChanges], [tagChanges] and
///   [schemaChanges] report each clip found private or public, whose tags
///   changed, or found foreign (schema `other`) or the app's own;
///   [privateRelPaths], [tagsByRelPath] and [foreignRelPaths] give all three
///   at launch. The clip library follows all of them (`LibraryWiring`).
///
/// The embedded streams and tags stay the source of truth: this cache is
/// derived data. A missing or corrupt file only means the backfill probes
/// again, and a failed write is logged, never thrown at a save flow.
///
/// Kept a plain class (not final) so tests can fake it.
class ClipMetadataCache {
  ClipMetadataCache({required this._paths, required this._logger});

  final AppPaths _paths;
  final AppLogger _logger;

  static const String fileName = 'clip_meta_v1.json';
  static const String _tag = 'CLIP_META';

  final Map<String, StampedClipMeta> _entries = <String, StampedClipMeta>{};

  /// Changes made since the last write started.
  bool _dirty = false;

  /// A flush was asked for since the running write took its snapshot.
  bool _flushWanted = false;

  /// The flush loop in flight, which every concurrent [flush] shares.
  Future<void>? _flushing;

  final StreamController<({String relPath, bool isPrivate})> _privacy =
      StreamController<({String relPath, bool isPrivate})>.broadcast();

  final StreamController<({String relPath, List<String> tags})> _tags =
      StreamController<({String relPath, List<String> tags})>.broadcast();

  final StreamController<({String relPath, bool isForeign})> _schema =
      StreamController<({String relPath, bool isForeign})>.broadcast();

  String get _file => '${_paths.supportIndexDir}/$fileName';

  /// Reads the sidecar. Call it once at startup, before the backfill. An
  /// entry [put] before the load finished wins over the file's.
  Future<void> load() async {
    try {
      final Map<String, StampedClipMeta> loaded = await _read(_file);
      loaded.forEach(
        (String relPath, StampedClipMeta entry) =>
            _entries.putIfAbsent(relPath, () => entry),
      );
    } on PathNotFoundException {
      // First launch, or the sidecar was never written: nothing cached yet.
    } on FileSystemException catch (error, stackTrace) {
      _ignoreUnreadable(error, stackTrace);
    } on FormatException catch (error, stackTrace) {
      _ignoreUnreadable(error, stackTrace);
    }
  }

  /// The cached facts of the clip at [relPath], or null when there are
  /// none for a file with [stamp] (never probed, or changed since).
  ClipMeta? lookup({required String relPath, required FileStamp stamp}) {
    final StampedClipMeta? entry = _entries[relPath];
    return entry != null && entry.stamp == stamp ? entry.meta : null;
  }

  /// The relPaths of the clips whose cached facts say they are private,
  /// whatever stamp the facts were read at: a private clip changed outside
  /// the app stays private until it is read again.
  Set<String> get privateRelPaths => <String>{
    for (final MapEntry<String, StampedClipMeta> entry in _entries.entries)
      if (entry.value.meta.isPrivate ?? false) entry.key,
  };

  /// Each clip a [put] or [remove] found private, or no longer private.
  Stream<({String relPath, bool isPrivate})> get privacyChanges =>
      _privacy.stream;

  /// The tags of every clip whose cached facts hold some, by relPath,
  /// whatever stamp the facts were read at (as [privateRelPaths]).
  Map<String, List<String>> get tagsByRelPath => <String, List<String>>{
    for (final MapEntry<String, StampedClipMeta> entry in _entries.entries)
      if (entry.value.meta.tags case final List<String> tags
          when tags.isNotEmpty)
        entry.key: tags,
  };

  /// Each clip a [put] or [remove] gave other tags than it had (an empty
  /// list: none left).
  Stream<({String relPath, List<String> tags})> get tagChanges => _tags.stream;

  /// The relPaths of the clips whose cached facts say they were not made
  /// by the app (`ClipSchema.other`), whatever stamp the facts were read
  /// at (as [privateRelPaths]).
  Set<String> get foreignRelPaths => <String>{
    for (final MapEntry<String, StampedClipMeta> entry in _entries.entries)
      if (_isForeign(entry.value.meta)) entry.key,
  };

  /// Each clip a [put] or [remove] found foreign, or the app's own.
  Stream<({String relPath, bool isForeign})> get schemaChanges =>
      _schema.stream;

  static bool _isForeign(ClipMeta meta) => meta.schema == ClipSchema.other;

  /// The places the clips carry (`ClipMeta.locationText`, found or typed),
  /// each once with how many clips have it, most used first and then by
  /// name: the clip editor's "Recent" places. Compared trimmed and without
  /// case, the first casing kept; private clips are left out, as their
  /// captions are hidden everywhere.
  List<({String place, int count})> recentPlaces() {
    final Map<String, ({String place, int count})> byKey =
        <String, ({String place, int count})>{};
    for (final StampedClipMeta entry in _entries.values) {
      final ClipMeta meta = entry.meta;
      if (meta.isPrivate ?? false) continue;
      final String place = meta.locationText?.trim() ?? '';
      if (place.isEmpty) continue;
      final String key = place.toLowerCase();
      final ({String place, int count})? seen = byKey[key];
      byKey[key] = (place: seen?.place ?? place, count: (seen?.count ?? 0) + 1);
    }
    final List<({String place, int count})> places = byKey.values.toList()
      ..sort((({String place, int count}) a, ({String place, int count}) b) {
        final int byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return a.place.toLowerCase().compareTo(b.place.toLowerCase());
      });
    return List<({String place, int count})>.unmodifiable(places);
  }

  /// Caches [meta] for the file at [relPath] with [stamp], in memory; call
  /// [flush] to persist. Throws an [ArgumentError] when [relPath] is not a
  /// path inside the videos folder (an absolute path must never be stored).
  void put({
    required String relPath,
    required FileStamp stamp,
    required ClipMeta meta,
  }) {
    _paths.absoluteFromVideos(relPath); // validates, throws ArgumentError
    final ClipMeta? before = _entries[relPath]?.meta;
    _entries[relPath] = StampedClipMeta(stamp: stamp, meta: meta);
    _dirty = true;
    _tellPrivacy(
      relPath,
      was: before?.isPrivate ?? false,
      isPrivate: meta.isPrivate ?? false,
    );
    _tellTags(relPath, was: before?.tags, tags: meta.tags);
    _tellSchema(
      relPath,
      was: before != null && _isForeign(before),
      isForeign: _isForeign(meta),
    );
  }

  /// Forgets the clip at [relPath] (the app deleted it), in memory.
  void remove(String relPath) {
    final StampedClipMeta? removed = _entries.remove(relPath);
    if (removed == null) return;
    _dirty = true;
    _tellPrivacy(
      relPath,
      was: removed.meta.isPrivate ?? false,
      isPrivate: false,
    );
    _tellTags(relPath, was: removed.meta.tags, tags: const <String>[]);
    _tellSchema(relPath, was: _isForeign(removed.meta), isForeign: false);
  }

  /// Closes [privacyChanges], [tagChanges] and [schemaChanges].
  Future<void> dispose() async {
    await _privacy.close();
    await _tags.close();
    await _schema.close();
  }

  void _tellSchema(
    String relPath, {
    required bool was,
    required bool isForeign,
  }) {
    if (was == isForeign || _schema.isClosed) return;
    _schema.add((relPath: relPath, isForeign: isForeign));
  }

  void _tellPrivacy(
    String relPath, {
    required bool was,
    required bool isPrivate,
  }) {
    if (was == isPrivate || _privacy.isClosed) return;
    _privacy.add((relPath: relPath, isPrivate: isPrivate));
  }

  /// Tells [tagChanges] when the tags differ. A clip whose facts are not
  /// read yet (null) has no tags as far as the library knows.
  void _tellTags(
    String relPath, {
    required List<String>? was,
    required List<String>? tags,
  }) {
    final List<String> before = was ?? const <String>[];
    final List<String> after = tags ?? const <String>[];
    if (_tags.isClosed || _sameTags(before, after)) return;
    _tags.add((relPath: relPath, tags: after));
  }

  static bool _sameTags(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// [put] and [flush]: the save flows' write-through.
  Future<void> write({
    required String relPath,
    required FileStamp stamp,
    required ClipMeta meta,
  }) {
    put(relPath: relPath, stamp: stamp, meta: meta);
    return flush();
  }

  /// Persists every change made so far. Completes when they are on disk,
  /// or logged as failed.
  Future<void> flush() {
    _flushWanted = true;
    return _flushing ??= _flushUntilClean();
  }

  Future<void> _flushUntilClean() async {
    try {
      while (_flushWanted) {
        _flushWanted = false;
        if (!_dirty) continue;
        _dirty = false;
        try {
          await _write(
            _paths.supportIndexDir,
            _file,
            Map<String, StampedClipMeta>.of(_entries),
          );
        } on FileSystemException catch (error, stackTrace) {
          _dirty = true;
          _logger.error(
            _tag,
            'Could not save the clip metadata cache',
            error: error,
            stackTrace: stackTrace,
          );
          return;
        }
      }
    } finally {
      _flushing = null;
    }
  }

  void _ignoreUnreadable(Object error, StackTrace stackTrace) =>
      _logger.warning(
        _tag,
        'Ignored an unreadable clip metadata cache; the backfill rebuilds it',
        error: error,
        stackTrace: stackTrace,
      );

  // Static, so the isolate closures capture only their plain arguments.

  static Future<Map<String, StampedClipMeta>> _read(String file) => Isolate.run(
    () => ClipMetaSidecar.decode(File(file).readAsStringSync()),
    debugName: 'clip-meta-load',
  );

  /// Writes a temporary file and renames it over the sidecar, so a crash
  /// mid-write never leaves a truncated cache.
  static Future<void> _write(
    String folder,
    String file,
    Map<String, StampedClipMeta> entries,
  ) => Isolate.run(() {
    Directory(folder).createSync(recursive: true);
    File('$file.tmp')
      ..writeAsStringSync(ClipMetaSidecar.encode(entries), flush: true)
      ..renameSync(file);
  }, debugName: 'clip-meta-save');
}
