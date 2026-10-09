import 'dart:io';
import 'dart:isolate';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/features/clips/data/clip_scan.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Lists one profile's clips from disk into a [ClipIndex].
///
/// - The listing and every `stat` run in a background isolate
///   ([Isolate.run]); only the finished, immutable [ClipScan] comes back.
/// - Default is the videos root, recursively, without the top-level
///   `Profiles/` and `Movies/` folders, compared by path segment, so a
///   profile or a folder named "Movies" hides nothing; a named profile is
///   `Profiles/<key>/`, recursively.
/// - A file counts only when `ClipNameCodec` accepts its whole basename (via
///   `ClipRef`), and every other `.mp4` name is logged under `[CALENDAR]`.
/// - A date-named video with another extension (`.mov`, `.m4v`, `.3gp`,
///   `.MP4`) directly in the profile's folder is listed apart as a foreign
///   file (`ClipScan.foreignFiles`), never indexed.
/// - Duplicates of one (day, ordinal) resolve in the index (shallowest
///   path first), and the hidden ones are logged too.
///
/// Kept a plain class (not final) so tests can hold a scan in flight.
class ClipScanner {
  ClipScanner({required this._paths, required this._logger});

  final AppPaths _paths;
  final AppLogger _logger;

  static const String _tag = 'CALENDAR';

  /// Scans [profile]'s folder. A profile whose folder does not exist yet
  /// has no clips. Throws a [StorageException] when the folder cannot be
  /// listed (e.g. storage permission revoked), so an unreadable diary never
  /// looks empty; an unreadable sub-folder is skipped and logged.
  Future<ClipScan> scan(ProfileKey profile) async {
    final String root = _paths.profileVideos(profile);
    final String rootRelPath = profile.isDefault
        ? ''
        : '${PathNames.profilesFolder}/${profile.value}/';
    final ClipScan scan;
    try {
      scan = await Isolate.run(
        () => _scanSync(profile: profile, root: root, rootRelPath: rootRelPath),
        debugName: 'clip-scan',
      );
    } on FileSystemException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StorageException(
          'Could not list the clips of profile ${profile.albumLabel}',
          cause: error,
        ),
        stackTrace,
      );
    }
    _log(scan);
    return scan;
  }

  /// Whether any folder [scan] listed was modified, removed or (for a
  /// missing profile folder) created since. A few async stats on the
  /// calling isolate, so a resume costs a full scan only when something
  /// changed. A file rewritten in place without adding or removing an entry
  /// is not detected; the app's own rewrites patch the index directly.
  Future<bool> hasChangedSince(ClipScan scan) async {
    for (final MapEntry<String, int> folder in scan.folderStamps.entries) {
      final FileStat stat = await FileStat.stat(folder.key);
      final int now = stat.type == FileSystemEntityType.notFound
          ? ClipScan.missingFolder
          : stat.modified.microsecondsSinceEpoch;
      if (now != folder.value) return true;
    }
    return false;
  }

  void _log(ClipScan scan) {
    final String label = scan.index.profile.albumLabel;
    final List<String> skipped = scan.skippedNames;
    if (skipped.isNotEmpty) {
      _logger.info(
        _tag,
        'Skipped ${_count(skipped.length, '.mp4 file')} that are not clip '
        'names in profile $label: ${skipped.join(', ')}',
      );
    }
    final List<ClipRef> hidden = scan.index.hiddenDuplicates;
    if (hidden.isNotEmpty) {
      _logger.info(
        _tag,
        'Hid ${_count(hidden.length, 'duplicate clip')} in profile $label: '
        '${hidden.map((ClipRef clip) => clip.relPath).join(', ')}',
      );
    }
    final List<String> foreign = scan.foreignFiles;
    if (foreign.isNotEmpty) {
      _logger.info(
        _tag,
        'Found ${_count(foreign.length, 'date-named video')} to process in '
        'profile $label: ${foreign.join(', ')}',
      );
    }
    final List<String> unreadable = scan.unreadableFolders;
    if (unreadable.isNotEmpty) {
      _logger.warning(
        _tag,
        'Could not list ${_count(unreadable.length, 'folder')} in profile '
        '$label: ${unreadable.join(', ')}',
      );
    }
  }

  static String _count(int count, String noun) =>
      '$count $noun${count == 1 ? '' : 's'}';

  /// The scan itself. Runs in a background isolate, where sync IO is fine.
  static ClipScan _scanSync({
    required ProfileKey profile,
    required String root,
    required String rootRelPath,
  }) {
    final List<IndexedClip> clips = <IndexedClip>[];
    final List<String> skipped = <String>[];
    final List<String> unreadable = <String>[];
    final List<String> foreign = <String>[];
    final Map<String, int> folders = <String, int>{};

    void walk(String folder, String relFolder, {required bool top}) {
      final Directory directory = Directory(folder);
      folders[folder] = directory.statSync().modified.microsecondsSinceEpoch;
      for (final FileSystemEntity entity in directory.listSync(
        followLinks: false,
      )) {
        final String name = PathNames.fileNameOf(entity.path);
        if (entity is Directory) {
          if (top &&
              profile.isDefault &&
              (name == PathNames.profilesFolder ||
                  name == PathNames.moviesFolder)) {
            continue;
          }
          try {
            walk('$folder$name/', '$relFolder$name/', top: false);
          } on FileSystemException {
            unreadable.add('$relFolder$name/');
          }
        } else if (entity is File) {
          final String relPath = '$relFolder$name';
          final ClipRef? ref = ClipRef.tryParse(
            profile: profile,
            relPath: relPath,
          );
          if (ref == null) {
            if (top && ClipScan.isForeignName(name)) {
              foreign.add(relPath);
            } else if (name.toLowerCase().endsWith('.mp4')) {
              skipped.add(relPath);
            }
            continue;
          }
          final FileStat stat = entity.statSync();
          // Deleted between the listing and the stat (the Gallery, a sync).
          if (stat.type == FileSystemEntityType.notFound) continue;
          clips.add(
            IndexedClip(
              ref: ref,
              stamp: FileStamp(
                sizeBytes: stat.size,
                modifiedMs: stat.modified.millisecondsSinceEpoch,
              ),
            ),
          );
        }
      }
    }

    if (FileSystemEntity.typeSync(root, followLinks: false) ==
        FileSystemEntityType.notFound) {
      folders[root] = ClipScan.missingFolder;
    } else {
      walk(root, rootRelPath, top: true);
    }
    return ClipScan(
      index: ClipIndex(profile: profile, clips: clips),
      skippedNames: List<String>.unmodifiable(skipped..sort()),
      unreadableFolders: List<String>.unmodifiable(unreadable..sort()),
      folderStamps: Map<String, int>.unmodifiable(folders),
      foreignFiles: List<String>.unmodifiable(foreign..sort()),
    );
  }
}
