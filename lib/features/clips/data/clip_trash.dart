import 'dart:io';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/path_names.dart';

/// Backups of clips the app replaced or deleted, kept in `AppPaths.trashDir`
/// until their Undo expires. Only `MediaPublisher` uses it.
///
/// Layout: one folder per entry, holding the backup at its path relative to
/// the videos folder, `<trashDir>/<id>/Profiles/Work/2024-01-05.mp4`, so the
/// entry itself says where the clip belongs (no manifest to lose). The clip's
/// kept original, when it has one, sits in the same entry under
/// [sourcesFolder] at its path relative to the Originals folder, so one Undo
/// brings both back.
///
/// An entry is created PENDING (`<id>.pending`) and committed once the
/// gallery write it protects has finished. A pending entry found at the
/// next launch means the app died mid-write, possibly after Android had
/// already removed the old clip; its backups are put back rather than
/// purged ([pendingEntries]).
///
/// Every method logs failures and never throws.
class ClipTrash {
  ClipTrash({
    required this._paths,
    required this._logger,
    required this._clock,
  });

  final AppPaths _paths;
  final AppLogger _logger;
  final Clock _clock;

  static const String _tag = 'MediaGallery';
  static const String _pending = '.pending';

  /// The sub-folder of an entry holding the clip's original, at its path
  /// relative to the Originals folder.
  static const String sourcesFolder = 'originals';

  /// Tells apart entries made in the same microsecond.
  int _sequence = 0;

  /// Copies the clip at [relPath] into a new pending entry and returns its
  /// id; null (logged) when the copy failed. A copy, not a move: the clip
  /// stays in the gallery until the gateway replaces or deletes it, so a
  /// crash in between never leaves it only in the trash.
  Future<String?> backUp(String relPath) async {
    final String id = '${_clock.now().microsecondsSinceEpoch}-${_sequence++}';
    try {
      final String backup = '${_pendingFolder(id)}/$relPath';
      await File(backup).parent.create(recursive: true);
      await File(_paths.absoluteFromVideos(relPath)).copy(backup);
      return id;
    } on FileSystemException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not back up $relPath',
        error: error,
        stackTrace: stackTrace,
      );
      await drop(id);
      return null;
    }
  }

  /// Copies the original at [from] (absolute, the clip's kept source) into
  /// entry [id] under [sourcesFolder] at [originalRelPath]. False (logged)
  /// when the copy failed; the entry stays, without it.
  Future<bool> backUpSource({
    required String id,
    required String originalRelPath,
    required String from,
  }) async {
    try {
      final String backup =
          '${_pendingFolder(id)}/$sourcesFolder/$originalRelPath';
      await File(backup).parent.create(recursive: true);
      await File(from).copy(backup);
      return true;
    } on FileSystemException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not back up the original $originalRelPath',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// The backup of the original at [originalRelPath] in entry [id],
  /// pending or not; null when there is none.
  Future<String?> sourceBackupOf({
    required String id,
    required String originalRelPath,
  }) => backupOf(id: id, relPath: '$sourcesFolder/$originalRelPath');

  /// The originals (paths relative to the Originals folder) backed up in
  /// entry [id], pending or not; empty when it holds none.
  Future<List<String>> sourcesIn(String id) async {
    final List<String> sources = <String>[];
    for (final String folder in <String>[_pendingFolder(id), _folder(id)]) {
      final String root = '$folder/$sourcesFolder';
      try {
        await for (final FileSystemEntity entity in Directory(
          root,
        ).list(recursive: true)) {
          if (entity is File) {
            sources.add(entity.path.substring(root.length + 1));
          }
        }
      } on PathNotFoundException {
        // No source in this entry.
      }
    }
    return sources;
  }

  /// Marks entry [id] finished, so the next launch purges it instead of
  /// putting its backups back.
  Future<void> commit(String id) async {
    try {
      await Directory(_pendingFolder(id)).rename(_folder(id));
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not close trash entry $id',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The backup of [relPath] in entry [id], pending or not; null when there
  /// is none (never made, or purged).
  Future<String?> backupOf({
    required String id,
    required String relPath,
  }) async {
    for (final String folder in <String>[_pendingFolder(id), _folder(id)]) {
      final String backup = '$folder/$relPath';
      if (await File(backup).exists()) return backup;
    }
    return null;
  }

  /// The clip backups (relative paths) in PENDING entry [id]; the
  /// originals under [sourcesFolder] are [sourcesIn]'s.
  Future<List<String>> relPathsIn(String id) async {
    final String root = _pendingFolder(id);
    return <String>[
      await for (final FileSystemEntity entity in Directory(
        root,
      ).list(recursive: true))
        if (entity is File && !entity.path.startsWith('$root/$sourcesFolder/'))
          entity.path.substring(root.length + 1),
    ];
  }

  /// Deletes entry [id], pending or not.
  Future<void> drop(String id) async {
    for (final String folder in <String>[_pendingFolder(id), _folder(id)]) {
      await _deleteFolder(folder);
    }
  }

  /// Every entry at launch: the ids of pending ones, after deleting every
  /// committed one (their Undo expired with the previous session).
  Future<List<String>> pendingEntries() async {
    final List<String> pending = <String>[];
    try {
      await for (final FileSystemEntity entity in Directory(
        _paths.trashDir,
      ).list()) {
        final String name = PathNames.fileNameOf(entity.path);
        if (name.endsWith(_pending)) {
          pending.add(name.substring(0, name.length - _pending.length));
        } else {
          await _deleteFolder(entity.path);
        }
      }
    } on PathNotFoundException {
      // Nothing was ever trashed.
    } on FileSystemException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not read the trash',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return pending;
  }

  String _folder(String id) => '${_paths.trashDir}/$id';

  String _pendingFolder(String id) => '${_folder(id)}$_pending';

  Future<void> _deleteFolder(String folder) async {
    try {
      await Directory(folder).delete(recursive: true);
    } on PathNotFoundException {
      // Not there.
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not empty trash folder $folder',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
