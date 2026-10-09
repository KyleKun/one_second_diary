import 'dart:async';
import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_scan.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// The app's clip library: one [ClipIndex] snapshot per profile, kept
/// current without re-listing the disk after every change. Screens derive
/// their clip and day counts from the snapshots.
///
/// How the snapshots stay current:
/// - [loadAll] scans every profile after the first frame, the active one
///   first, so profile counts are free afterwards;
/// - the app's own writes patch the snapshot directly ([clipAdded],
///   [clipReplaced], [clipRemoved], [profileRemoved]): no rescan;
/// - [rescanChanged] runs on `AppLifecycleState.resumed` and rescans only
///   the profiles whose folders changed (Gallery or Files-app edits);
/// - [rescan] runs on demand (pull-to-refresh, a new profile) and always
///   lists;
/// - a rescan that finds the same files keeps the current snapshot and
///   emits nothing.
///
/// A scan never loses a concurrent change: patches made while it is in
/// flight are replayed onto its result, and a rescan asked for during a
/// scan lists again once it ends, so an older listing never overwrites a
/// newer one.
///
/// Which clips are private, which tags each carries and which were not
/// made by the app (the schema marker) is in the clips' files
/// (`ClipPrivacyTag`, `KeywordsTag`, the artist tag), which a listing does
/// not read: the repository is told ([privateClipsKnown], [clipTagsKnown]
/// and [foreignClipsKnown] at launch, [privacyKnown], [tagsKnown] and
/// [schemaKnown] for each clip marked or read since) and marks every
/// snapshot it publishes, rescans included. A clip rewritten in place stays
/// private and tagged; a deleted clip's name does not.
///
/// Which clips have a kept original recording beside the diary
/// ([sourcesKnown], the Originals folder's names scan) marks every snapshot
/// the same way; a write never changes it, the scan that follows the write
/// does.
///
/// The date-named videos with another extension a scan found beside the
/// clips ([foreignFilesOf]) are kept per profile for the processing sheet.
///
/// Kept a plain class (not final) so screen tests can fake it.
class ClipRepository {
  ClipRepository({
    required this._scanner,
    required this._paths,
    required this._logger,
  });

  final ClipScanner _scanner;
  final AppPaths _paths;
  final AppLogger _logger;

  static const String _tag = 'CALENDAR';

  /// Per-profile state, in load order (the active profile first).
  final Map<ProfileKey, _Library> _libraries = <ProfileKey, _Library>{};

  final StreamController<_Update> _updates =
      StreamController<_Update>.broadcast();

  /// The relPaths of the clips known to be private, of every profile,
  /// loaded or not.
  final Set<String> _private = <String>{};

  /// The tags of the clips known to carry some, by relPath, of every
  /// profile, loaded or not.
  final Map<String, List<String>> _tags = <String, List<String>>{};

  /// The relPaths of the clips known not to be the app's own (cached
  /// schema `other`), of every profile, loaded or not.
  final Set<String> _foreign = <String>{};

  /// The relPaths of the clips whose original recording is kept beside
  /// the diary, of every profile, loaded or not.
  final Set<String> _sources = <String>{};

  /// The current snapshot of every loaded profile, in load order (the
  /// profile active at [loadAll] first).
  Map<ProfileKey, ClipIndex> get snapshots =>
      Map<ProfileKey, ClipIndex>.unmodifiable(<ProfileKey, ClipIndex>{
        for (final MapEntry<ProfileKey, _Library> entry in _libraries.entries)
          if (entry.value.index != null) entry.key: entry.value.index!,
      });

  /// The current snapshot of [profile]; null before its first scan.
  ClipIndex? snapshotOf(ProfileKey profile) => _libraries[profile]?.index;

  /// The date-named videos with another extension the last scan of
  /// [profile] found directly in its folder (`ClipScan.foreignFiles`,
  /// relPaths); empty before its first scan.
  List<String> foreignFilesOf(ProfileKey profile) =>
      _libraries[profile]?.lastScan?.foreignFiles ?? const <String>[];

  /// [profile]'s current snapshot (when there is one), then every new one.
  /// While [profile] has no snapshot yet, a failed scan arrives as a
  /// [StorageException] error event, so a screen can show that the diary
  /// could not be read instead of waiting forever. A removed profile emits
  /// an empty index.
  Stream<ClipIndex> watch(ProfileKey profile) {
    late final StreamController<ClipIndex> controller;
    StreamSubscription<_Update>? subscription;
    controller = StreamController<ClipIndex>(
      onListen: () {
        final ClipIndex? current = snapshotOf(profile);
        if (current != null) controller.add(current);
        subscription = _updates.stream
            .where((_Update update) => update.profile == profile)
            .listen(
              (_Update update) => switch (update) {
                _Published(:final ClipIndex index) => controller.add(index),
                _Failed(:final Object error, :final StackTrace stackTrace) =>
                  controller.addError(error, stackTrace),
              },
              onDone: controller.close,
            );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  /// Scans [profiles] and [active], [active] first, one after the other,
  /// publishing each snapshot as soon as it is ready. A profile that cannot
  /// be read is logged and reported on its [watch] stream; the others still
  /// load.
  Future<void> loadAll({
    required ProfileKey active,
    required Iterable<ProfileKey> profiles,
  }) async {
    final Set<ProfileKey> order = <ProfileKey>{active, ...profiles};
    for (final ProfileKey profile in order) {
      _libraries.putIfAbsent(profile, _Library.new);
    }
    for (final ProfileKey profile in order) {
      await _rescanReported(profile);
    }
  }

  /// Rescans, [active] first, every loaded profile whose folders changed
  /// since its last scan, plus any whose last scan failed. Call it on
  /// `AppLifecycleState.resumed`.
  Future<void> rescanChanged({required ProfileKey active}) async {
    final Set<ProfileKey> order = <ProfileKey>{
      if (_libraries.containsKey(active)) active,
      ..._libraries.keys,
    };
    for (final ProfileKey profile in order) {
      final ClipScan? last = _libraries[profile]?.lastScan;
      if (last == null || await _scanner.hasChangedSince(last)) {
        await _rescanReported(profile);
      }
    }
  }

  /// Lists [profile]'s folder again and returns its snapshot (the current
  /// one when nothing changed). Use it for pull-to-refresh and for a
  /// profile that was just created. Throws a [StorageException] when the
  /// folder cannot be read; the previous snapshot stays.
  Future<ClipIndex> rescan(ProfileKey profile) {
    final _Library library = _libraries.putIfAbsent(profile, _Library.new);
    library.rescanWanted = true;
    return library.running ??= _scanUntilCurrent(profile, library);
  }

  /// [profile]'s snapshot, listed again first when its folders changed
  /// since its last scan (or it was never scanned); a few async stats
  /// otherwise. The save flow names a new clip from it, so a clip copied
  /// into a sub-folder while the app was open still counts for the day's
  /// next ordinal and is never hidden by the new clip. Throws a
  /// [StorageException] like [rescan].
  Future<ClipIndex> rescanIfChanged(ProfileKey profile) async {
    final _Library? library = _libraries[profile];
    final ClipIndex? current = library?.index;
    final ClipScan? last = library?.lastScan;
    if (current == null ||
        last == null ||
        library?.running != null ||
        await _scanner.hasChangedSince(last)) {
      return rescan(profile);
    }
    return current;
  }

  /// The app published a new clip file at [clip].relPath. A new clip is
  /// never private and has no tags, whatever a file that had its name was.
  Future<void> clipAdded(ClipRef clip) {
    _private.remove(clip.relPath);
    _tags.remove(clip.relPath);
    _foreign.remove(clip.relPath);
    return _upsert(clip);
  }

  /// The app rewrote the clip at [clip].relPath (a subtitle or privacy
  /// edit, a safe replace): its stamp changes, so caches keyed by it
  /// refresh. It stays private, and tagged, as it was.
  Future<void> clipReplaced(ClipRef clip) => _upsert(clip);

  /// The app deleted [clip]. A duplicate it hid becomes visible, as a
  /// rescan would show.
  void clipRemoved(ClipRef clip) {
    _private.remove(clip.relPath);
    _tags.remove(clip.relPath);
    _foreign.remove(clip.relPath);
    _patch(clip.profile, (ClipIndex index) => index.withoutClip(clip.relPath));
  }

  /// [profile] and its folder were deleted: it leaves [snapshots], and its
  /// watchers get an empty index.
  void profileRemoved(ProfileKey profile) {
    _libraries.remove(profile);
    bool ofProfile(String relPath) =>
        ClipRef.tryParse(profile: profile, relPath: relPath) != null;
    _private.removeWhere(ofProfile);
    _tags.removeWhere((String relPath, List<String> _) => ofProfile(relPath));
    _foreign.removeWhere(ofProfile);
    _sources.removeWhere(ofProfile);
    _emit(_Published(profile, ClipIndex.empty(profile)));
  }

  /// The clips at [relPaths] are private (what the metadata cache knows at
  /// launch). Call it before [loadAll], so the first snapshots are marked.
  void privateClipsKnown(Iterable<String> relPaths) {
    _private.addAll(relPaths);
    for (final ProfileKey profile in _libraries.keys.toList()) {
      _patch(profile, (ClipIndex index) => index.withPrivate(_private));
    }
  }

  /// The clip at [relPath] is private, or public: the user marked it, or
  /// its file was read. Its profile's snapshot follows at once; a file no
  /// snapshot holds is remembered for the scan that finds it.
  void privacyKnown(String relPath, {required bool private}) {
    if (private) {
      _private.add(relPath);
    } else {
      _private.remove(relPath);
    }
    for (final ProfileKey profile in _libraries.keys.toList()) {
      _patch(
        profile,
        (ClipIndex index) => index.withPrivacy(relPath, private: private),
      );
    }
  }

  /// The clips at the keys of [tagsByRelPath] carry those tags (what the
  /// metadata cache knows at launch). Call it before [loadAll], so the
  /// first snapshots carry them.
  void clipTagsKnown(Map<String, List<String>> tagsByRelPath) {
    _tags.addAll(tagsByRelPath);
    for (final ProfileKey profile in _libraries.keys.toList()) {
      _patch(profile, (ClipIndex index) => index.withClipTags(_tags));
    }
  }

  /// The clip at [relPath] carries exactly [tags] (empty: none): the user
  /// set them, or its file was read. Its profile's snapshot follows at
  /// once; a file no snapshot holds is remembered for the scan that finds
  /// it.
  void tagsKnown(String relPath, List<String> tags) {
    if (tags.isEmpty) {
      _tags.remove(relPath);
    } else {
      _tags[relPath] = tags;
    }
    for (final ProfileKey profile in _libraries.keys.toList()) {
      _patch(profile, (ClipIndex index) => index.withTags(relPath, tags));
    }
  }

  /// The clips at [relPaths] were not made by the app (what the metadata
  /// cache knows at launch). Call it before [loadAll], so the first
  /// snapshots are marked.
  void foreignClipsKnown(Iterable<String> relPaths) {
    _foreign.addAll(relPaths);
    for (final ProfileKey profile in _libraries.keys.toList()) {
      _patch(profile, (ClipIndex index) => index.withForeign(_foreign));
    }
  }

  /// The clip at [relPath] was read: [foreign] when its file carries no
  /// schema marker of the app's. Its profile's snapshot follows at once; a
  /// file no snapshot holds is remembered for the scan that finds it.
  void schemaKnown(String relPath, {required bool foreign}) {
    if (foreign) {
      _foreign.add(relPath);
    } else {
      _foreign.remove(relPath);
    }
    for (final ProfileKey profile in _libraries.keys.toList()) {
      _patch(
        profile,
        (ClipIndex index) => index.withSchema(relPath, foreign: foreign),
      );
    }
  }

  /// Exactly the clips at [relPaths] have a kept original recording (the
  /// Originals folder's names, scanned at launch and after each write
  /// there). Every snapshot follows at once; a file no snapshot holds is
  /// remembered for the scan that finds it.
  void sourcesKnown(Iterable<String> relPaths) {
    _sources
      ..clear()
      ..addAll(relPaths);
    for (final ProfileKey profile in _libraries.keys.toList()) {
      _patch(profile, (ClipIndex index) => index.withSources(_sources));
    }
  }

  /// Closes every [watch] stream.
  Future<void> dispose() => _updates.close();

  Future<ClipIndex> _scanUntilCurrent(
    ProfileKey profile,
    _Library library,
  ) async {
    try {
      while (true) {
        library
          ..rescanWanted = false
          ..journal = <_Patch>[];
        final ClipScan scan = await _scanner.scan(profile);
        ClipIndex index = scan.index
            .withPrivate(_private)
            .withClipTags(_tags)
            .withForeign(_foreign)
            .withSources(_sources);
        for (final _Patch patch in library.journal!) {
          index = patch(index);
        }
        library
          ..journal = null
          ..lastScan = scan;
        final ClipIndex? current = library.index;
        if (current == null || !current.hasSameFilesAs(index)) {
          _publish(profile, library, index);
        }
        if (!library.rescanWanted) return library.index ?? index;
      }
    } on AppException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not scan profile ${profile.albumLabel}',
        error: error,
        stackTrace: stackTrace,
      );
      if (library.index == null && identical(_libraries[profile], library)) {
        _emit(_Failed(profile, error, stackTrace));
      }
      rethrow;
    } finally {
      library
        ..journal = null
        ..running = null;
    }
  }

  /// [rescan], for background callers: a failure is already logged and
  /// reported on the watch stream, so it does not stop the caller.
  Future<void> _rescanReported(ProfileKey profile) async {
    try {
      await rescan(profile);
    } on AppException {
      // Logged and reported by _scanUntilCurrent.
    }
  }

  Future<void> _upsert(ClipRef clip) async {
    final FileStat stat = await FileStat.stat(
      _paths.absoluteFromVideos(clip.relPath),
    );
    if (stat.type == FileSystemEntityType.notFound) {
      _logger.warning(
        _tag,
        'Ignored a write to a file that does not exist: ${clip.relPath}',
      );
      return;
    }
    final IndexedClip entry = IndexedClip(
      ref: clip,
      stamp: FileStamp(
        sizeBytes: stat.size,
        modifiedMs: stat.modified.millisecondsSinceEpoch,
      ),
    );
    _patch(
      clip.profile,
      (ClipIndex index) => index
          .withClip(entry)
          .withPrivacy(clip.relPath, private: _private.contains(clip.relPath))
          .withTags(clip.relPath, _tags[clip.relPath] ?? const <String>[])
          .withSchema(clip.relPath, foreign: _foreign.contains(clip.relPath))
          .withSource(clip.relPath, has: _sources.contains(clip.relPath)),
    );
  }

  /// Applies [patch] to [profile]'s snapshot now, and to the result of a
  /// scan in flight when it lands. A profile never scanned has no snapshot
  /// to patch; its first scan will see the file.
  void _patch(ProfileKey profile, _Patch patch) {
    final _Library? library = _libraries[profile];
    if (library == null) return;
    library.journal?.add(patch);
    final ClipIndex? current = library.index;
    if (current == null) return;
    final ClipIndex next = patch(current);
    if (!identical(next, current)) _publish(profile, library, next);
  }

  void _publish(ProfileKey profile, _Library library, ClipIndex index) {
    // A profile removed while its scan was in flight stays removed.
    if (!identical(_libraries[profile], library)) return;
    library.index = index;
    _emit(_Published(profile, index));
  }

  void _emit(_Update update) {
    if (!_updates.isClosed) _updates.add(update);
  }
}

typedef _Patch = ClipIndex Function(ClipIndex index);

/// The repository's state for one profile.
final class _Library {
  ClipIndex? index;

  /// The last successful scan (its folder stamps gate [rescanChanged]).
  ClipScan? lastScan;

  /// The scan loop in flight, which every concurrent [rescan] shares.
  Future<ClipIndex>? running;

  /// A rescan was asked for since the running scan listed the disk.
  bool rescanWanted = false;

  /// Patches made since the running scan started listing; null when idle.
  List<_Patch>? journal;
}

sealed class _Update {
  const _Update(this.profile);

  final ProfileKey profile;
}

final class _Published extends _Update {
  const _Published(super.profile, this.index);

  final ClipIndex index;
}

final class _Failed extends _Update {
  const _Failed(super.profile, this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}
