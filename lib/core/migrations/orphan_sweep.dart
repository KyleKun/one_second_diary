import 'dart:io';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';

/// Deletes what a killed job left behind:
/// - the movie temps older installs left in the gallery:
///   `yyyy-MM-dd_<digits>.mp4` (`ClipNameCodec.isLegacyMovieTemp`) directly
///   in a profile's own folder (the videos folder or `Profiles/<key>/`) and
///   beside the clip of that day, the only place they were written. A
///   look-alike in a user-made sub-folder, or without its clip, is the
///   user's file and stays. Temps go with a plain unlink, never through the
///   media store: after a reinstall Android refuses the unlink, and the
///   media store would then ask for consent at every launch, so such a temp
///   stays, logged;
/// - everything in `AppPaths.scratchDir`: per-job folders never outlive the
///   process that made them;
/// - COMMITTED entries of `AppPaths.trashDir` older than [trashRetention],
///   a backstop: `MediaPublisher.purgeTrash()` already empties them at every
///   launch. A pending entry (`<id>.pending`) is never swept, whatever its
///   age: on Android the media store deletes the old clip before inserting
///   the new one, so a replace killed in between leaves the backup as the
///   only copy, and only `purgeTrash()` may put it back or drop it.
///
/// Nothing else in the temporary or cache folders is touched (they are the
/// same folder on devices, and the camera and pickers write there).
///
/// Run it at launch, after `LegacyFolderMigration` and before any media
/// job, while [run]'s `isMediaBusy` is false.
final class OrphanSweep {
  OrphanSweep({
    required this._paths,
    required this._clock,
    required this._logger,
  });

  final AppPaths _paths;
  final Clock _clock;
  final AppLogger _logger;

  static const String _tag = 'MIGRATION';

  /// How long a committed trash entry is kept, counted from when it was
  /// moved there.
  static const Duration trashRetention = Duration(days: 7);

  /// The suffix of a trash entry whose gallery write never finished
  /// (`ClipTrash`'s layout).
  static const String _pendingTrash = '.pending';

  /// Sweeps, checking [isMediaBusy] before every deletion: as soon as a
  /// media job runs, the sweep stops (the job may own any of these files).
  /// Failures are logged and skipped, never thrown.
  Future<void> run({required bool Function() isMediaBusy}) async {
    int deleted = 0;
    for (final FileSystemEntity entry in <FileSystemEntity>[
      ...await _legacyTemps(),
      ...await _entriesOf(_paths.scratchDir),
      ...await _staleTrash(),
    ]) {
      if (isMediaBusy()) return _stopped(deleted);
      if (await _delete(entry)) deleted++;
    }
    if (deleted > 0) _logger.info(_tag, 'Swept $deleted orphaned file(s)');
  }

  void _stopped(int deleted) => _logger.info(
    _tag,
    'Sweep stopped for a media job after $deleted orphaned file(s)',
  );

  /// The movie temps of older installs: files directly in a profile's own
  /// folder, each beside the clip it copied.
  Future<List<File>> _legacyTemps() async {
    final List<File> temps = <File>[];
    for (final String folder in <String>[
      _paths.videos,
      for (final FileSystemEntity entity in await _entriesOf(
        '${_paths.videos}${PathNames.profilesFolder}',
      ))
        if (entity is Directory) entity.path,
    ]) {
      final List<File> files = <File>[
        for (final FileSystemEntity entity in await _entriesOf(folder))
          if (entity is File) entity,
      ];
      final Set<String> names = <String>{
        for (final File file in files) _nameOf(file),
      };
      temps.addAll(<File>[
        for (final File file in files)
          if (_isTempOfClipIn(names, _nameOf(file))) file,
      ]);
    }
    return temps;
  }

  /// Whether [name] is a movie temp of a clip in [siblings]: each temp is
  /// named `<clip stem>_<random>.mp4` in the clip's own folder, so a
  /// look-alike without its clip there is a file the user made.
  static bool _isTempOfClipIn(Set<String> siblings, String name) {
    if (!ClipNameCodec.isLegacyMovieTemp(name)) return false;
    final LocalDay? day = LocalDay.tryParseStem(name.substring(0, 10));
    return day != null && siblings.contains(ClipNameCodec.format(day));
  }

  static String _nameOf(FileSystemEntity entity) =>
      PathNames.fileNameOf(entity.path);

  /// The committed trash entries moved there more than [trashRetention]
  /// ago. Their status-change time is the move: a rename keeps a clip's
  /// modification time, which may be years old.
  Future<List<FileSystemEntity>> _staleTrash() async {
    final DateTime cutoff = _clock.now().subtract(trashRetention);
    return <FileSystemEntity>[
      for (final FileSystemEntity entry in await _entriesOf(_paths.trashDir))
        if (!entry.path.endsWith(_pendingTrash) &&
            (await entry.stat()).changed.isBefore(cutoff))
          entry,
    ];
  }

  Future<List<FileSystemEntity>> _entriesOf(String folder) async {
    try {
      return await Directory(folder).list(followLinks: false).toList();
    } on PathNotFoundException {
      return <FileSystemEntity>[];
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Cannot list $folder',
        error: error,
        stackTrace: stackTrace,
      );
      return <FileSystemEntity>[];
    }
  }

  Future<bool> _delete(FileSystemEntity entry) async {
    try {
      await entry.delete(recursive: true);
      return true;
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Cannot delete ${entry.path}',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
