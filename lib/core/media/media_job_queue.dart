import 'dart:async';
import 'dart:io';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

/// Runs the media engine's jobs one at a time, in the order they were
/// submitted, with no priorities.
///
/// Each job gets its own scratch folder under `AppPaths.scratchDir`, created
/// before it starts and deleted when it ends, whether it succeeded, failed
/// or was cancelled, so two jobs never clobber each other's files.
final class MediaJobQueue {
  MediaJobQueue({required this._paths, required this._logger});

  final AppPaths _paths;
  final AppLogger _logger;

  Future<void> _tail = Future<void>.value();

  /// Runs [job] after every job submitted before it, with its own scratch
  /// folder, and completes with its result or its error. A failed job never
  /// blocks the ones after it.
  Future<T> run<T>(Future<T> Function(Directory scratch) job) {
    final Completer<T> result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await _inScratch(job));
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<T> _inScratch<T>(Future<T> Function(Directory scratch) job) async {
    final Directory root = Directory(_paths.scratchDir);
    await root.create(recursive: true);
    final Directory scratch = await root.createTemp('job-');
    try {
      return await job(scratch);
    } finally {
      await _delete(scratch);
    }
  }

  Future<void> _delete(Directory scratch) async {
    try {
      await scratch.delete(recursive: true);
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        'ffmpeg',
        'Could not delete the job folder ${scratch.path}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
