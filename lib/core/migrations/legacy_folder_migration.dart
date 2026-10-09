import 'dart:io';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/migrations/legacy_migration_event.dart';
import 'package:one_second_diary/core/migrations/legacy_migration_report.dart';
import 'package:one_second_diary/core/platform/media_store_gateway.dart';
import 'package:one_second_diary/core/platform/wakelock_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Moves the videos that older Android installs kept outside DCIM into the
/// DCIM layout: clips from `<storage root>/OneSecondDiary/` and movies from
/// `<storage root>/OSD-Movies/`.
///
/// - Android only; nothing to do once every old video is in the diary
///   ([isNeeded]), so a folder whose originals can't be deleted is reported
///   once, not at every launch;
/// - every clip is copied to private staging, published through the media
///   store into its album, and its original deleted only once the publish
///   is confirmed and the file is found at its destination with the staged
///   size (a true alone is not trusted);
/// - a clip under `Profiles/<name>/` registers that profile without a
///   canvas, so it stays landscape like every clip in those folders;
/// - the movies move only when every clip did, and the old folders are
///   deleted only when everything in them moved;
/// - the wakelock is held while it runs (best effort: a refused wakelock is
///   logged and never stops the move);
/// - a file already at the destination is never replaced (a publish would
///   replace it). The same size means a run stopped after publishing it,
///   so only the original goes; a different file keeps the original and
///   reports it;
/// - the report counts only what this run moved, never a video an earlier
///   run already put in the diary;
/// - only the top-level `Logs/` folder is skipped (a profile named "Blogs"
///   is moved);
/// - sub-folders keep their place: flattened into the root, two same-named
///   clips would replace each other;
/// - a movie's original is deleted only after its publish is confirmed;
/// - names ending in `.MP4` move too; movie temps
///   (`ClipNameCodec.isLegacyMovieTemp`) never do, and go with the folder.
///
/// Every other file in an old folder (old logs, temps) is deleted with it.
/// Run it at launch, before any media job, once `isNeeded` says so, behind
/// a non-dismissable dialog.
final class LegacyFolderMigration {
  LegacyFolderMigration({
    required this._paths,
    required this._mediaStore,
    required this._wakelock,
    required this._profiles,
    required this._logger,
    required this._isAndroid,
  });

  final AppPaths _paths;
  final MediaStoreGateway _mediaStore;
  final WakelockGateway _wakelock;
  final ProfilesRepository _profiles;
  final AppLogger _logger;
  final bool _isAndroid;

  static const String _tag = 'MIGRATION';

  String get _oldClips => _paths.legacyAndroidVideos;
  String get _oldMovies => _paths.legacyAndroidMovies;
  String get _staging => '${_paths.scratchDir}/legacy_migration';

  /// Whether there is anything left to move: on Android, an old clip or
  /// movie whose destination is still free.
  ///
  /// An old folder alone is not enough. When the originals can't be deleted
  /// (after a reinstall Android refuses to let the app unlink them), the
  /// folder stays although every video is in the diary; the run that got
  /// them there reported it, and asking again would bring the blocking
  /// dialog back at every launch. An old video whose destination holds a
  /// different file is decided too: [run] kept it and reported it once, and
  /// no later run can move it.
  ///
  /// An old folder that can't be listed (no storage access, Android 9 and
  /// older) is logged and left alone: a run could only fail on it behind
  /// the blocking dialog.
  Future<bool> isNeeded() async {
    if (!_isAndroid) return false;
    try {
      for (final (_, String destination) in await _oldVideos()) {
        if (!await File(destination).exists()) return true;
      }
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Cannot list the old folders; left as they are',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
    return false;
  }

  /// Every old clip, then every old movie, with its destination.
  Future<List<(File, String)>> _oldVideos() async => <(File, String)>[
    for (final String relative in await _videosUnder(_oldClips, skipLogs: true))
      (File('$_oldClips$relative'), _paths.absoluteFromVideos(relative)),
    for (final String relative in await _videosUnder(_oldMovies))
      (
        File('$_oldMovies$relative'),
        _paths.absoluteFromVideos('${PathNames.moviesFolder}/$relative'),
      ),
  ];

  /// Runs the migration: [LegacyMigrationProgress] as files move, then
  /// exactly one [LegacyMigrationFinished]. When nothing is needed, only
  /// the [LegacyMigrationFinished] with `LegacyMigrationReport.nothingToDo`.
  ///
  /// Ends with an error instead when an old folder can't be read or a
  /// preference can't be written; the wakelock is released either way.
  Stream<LegacyMigrationEvent> run() async* {
    if (!await isNeeded()) {
      yield const LegacyMigrationFinished(LegacyMigrationReport.nothingToDo);
      return;
    }
    final List<String> clips = await _videosUnder(_oldClips, skipLogs: true);
    final List<String> movies = await _videosUnder(_oldMovies);
    final int total = clips.length + movies.length;
    _logger.info(
      _tag,
      'Moving ${clips.length} clip(s) from $_oldClips and ${movies.length} '
      'movie(s) from $_oldMovies',
    );
    await _holdWakelock(on: true);
    try {
      int done = 0;
      yield LegacyMigrationProgress(done: done, total: total);
      final List<String> failed = <String>[];
      int clipsMoved = 0;
      for (final String relative in clips) {
        final List<String> segments = relative.split('/');
        if (segments.length > 2 && segments.first == PathNames.profilesFolder) {
          await _profiles.addFound(ProfileKey(segments[1]));
        }
        switch (await _move(
          File('$_oldClips$relative'),
          destination: _paths.absoluteFromVideos(relative),
        )) {
          case _MoveOutcome.moved:
            clipsMoved++;
          case _MoveOutcome.movedEarlier:
            break;
          case _MoveOutcome.kept:
            failed.add('${AppPaths.folderName}/$relative');
        }
        yield LegacyMigrationProgress(done: ++done, total: total);
      }
      final bool clipsDone = failed.isEmpty;
      int moviesMoved = 0;
      if (clipsDone) {
        for (final String relative in movies) {
          switch (await _move(
            File('$_oldMovies$relative'),
            destination: _paths.absoluteFromVideos(
              '${PathNames.moviesFolder}/$relative',
            ),
          )) {
            case _MoveOutcome.moved:
              moviesMoved++;
            case _MoveOutcome.movedEarlier:
              break;
            case _MoveOutcome.kept:
              failed.add('OSD-Movies/$relative');
          }
          yield LegacyMigrationProgress(done: ++done, total: total);
        }
      }
      await _deleteFolder(_staging);
      final bool clipsFolderGone = clipsDone && await _deleteFolder(_oldClips);
      final bool moviesFolderGone =
          failed.isEmpty && await _deleteFolder(_oldMovies);
      final LegacyMigrationReport report = LegacyMigrationReport(
        clipsMigrated: clipsMoved,
        failed: failed,
        moviesMigrated: moviesMoved,
        oldFoldersRemoved: clipsFolderGone && moviesFolderGone,
      );
      _logger.info(
        _tag,
        'Moved $clipsMoved clip(s) and $moviesMoved movie(s); kept '
        '${failed.length}; old folders removed: '
        '${report.oldFoldersRemoved}',
      );
      yield LegacyMigrationFinished(report);
    } finally {
      await _holdWakelock(on: false);
    }
  }

  /// Turns the wakelock [on] or off, best effort: it only keeps the screen
  /// on while files move, so a platform that refuses it is logged and the
  /// migration goes on.
  Future<void> _holdWakelock({required bool on}) async {
    try {
      await (on ? _wakelock.enable() : _wakelock.disable());
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not ${on ? 'take' : 'release'} the wakelock',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The videos under [root], relative to it and sorted: names ending in
  /// `.mp4` in any case, except movie temps and, with [skipLogs], the
  /// top-level `Logs/` folder.
  Future<List<String>> _videosUnder(
    String root, {
    bool skipLogs = false,
  }) async {
    final List<String> videos = <String>[];
    try {
      await for (final FileSystemEntity entity in Directory(
        root,
      ).list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final String relative = entity.path.substring(root.length);
        final String name = PathNames.fileNameOf(relative);
        if (!name.toLowerCase().endsWith('.mp4') ||
            ClipNameCodec.isLegacyMovieTemp(name) ||
            (skipLogs && relative.startsWith('Logs/'))) {
          continue;
        }
        videos.add(relative);
      }
    } on PathNotFoundException {
      // No such old folder.
    }
    return videos..sort();
  }

  /// Moves [original] to [destination] through the media store and says
  /// whether, and when, it got there. The original is deleted only after
  /// the media store confirmed the publish AND the file is at [destination]
  /// with the staged copy's size.
  ///
  /// A file already at [destination] is never replaced: with the same size
  /// it is this one, published by an earlier run that could not delete the
  /// original. Deleting it now finishes that move; when it still can't be
  /// deleted, this run changed nothing ([_MoveOutcome.movedEarlier]).
  /// Otherwise it is a different file and the original stays.
  Future<_MoveOutcome> _move(
    File original, {
    required String destination,
  }) async {
    try {
      final int there = await File(destination).length();
      if (there == await original.length()) {
        return await _deleteOriginal(original)
            ? _MoveOutcome.moved
            : _MoveOutcome.movedEarlier;
      }
      _logger.warning(
        _tag,
        'A different ${_paths.relativeToVideos(destination)} is already in '
        'the diary; kept ${original.path}',
      );
      return _MoveOutcome.kept;
    } on PathNotFoundException {
      // The destination is free.
    }
    final String staged = '$_staging/${_paths.relativeToVideos(destination)}';
    await File(staged).parent.create(recursive: true);
    await original.copy(staged);
    final int size = await File(staged).length();
    final bool published = await _mediaStore.publish(
      tempFilePath: staged,
      album: _paths.albumFor(destination),
    );
    if (!published) {
      _logger.warning(
        _tag,
        'The media store refused ${original.path}; kept it',
      );
      return _MoveOutcome.kept;
    }
    if (!await _landed(destination, size: size)) {
      _logger.warning(
        _tag,
        'The media store reported ${original.path} published, but '
        '${_paths.relativeToVideos(destination)} is not there with $size '
        'bytes; kept the original',
      );
      return _MoveOutcome.kept;
    }
    await _deleteOriginal(original);
    return _MoveOutcome.moved;
  }

  /// Whether a file of [size] bytes is at [destination]. A publish the
  /// media store reported done is not trusted alone: `media_store_plus` may
  /// answer true with the file elsewhere (from Android 10, an insert whose
  /// name exists on disk without a MediaStore row gets a unique
  /// `… (1).mp4` name), and the original must not be deleted then.
  static Future<bool> _landed(String destination, {required int size}) async {
    try {
      return await File(destination).length() == size;
    } on FileSystemException {
      return false;
    }
  }

  /// Deletes a moved original and says whether it is gone; one left behind
  /// goes with its old folder.
  Future<bool> _deleteOriginal(File original) async {
    try {
      await original.delete();
      return true;
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Cannot delete the moved ${original.path}',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Deletes [folder] with everything in it, and says whether it is gone.
  Future<bool> _deleteFolder(String folder) async {
    try {
      await Directory(folder).delete(recursive: true);
      return true;
    } on PathNotFoundException {
      return true;
    } on FileSystemException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Cannot delete $folder',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}

/// What [LegacyFolderMigration._move] did with one old video.
enum _MoveOutcome {
  /// This run moved it: published now, or its original deleted now after
  /// an earlier run published it.
  moved,

  /// An earlier run published it and its original still can't be deleted:
  /// this run changed nothing, so it is neither counted nor failed.
  movedEarlier,

  /// The original stays where it was, reported as failed.
  kept,
}
