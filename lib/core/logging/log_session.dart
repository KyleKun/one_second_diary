import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/file_log_sink.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';

/// One log file per launch: `<logsDir>/yyyy-MM-dd_HH-mm-ss.txt`, kept for 7
/// days and zipped by the bug report.
///
/// Bootstrap calls [open] right after `AppPaths.resolve()`, before anything
/// logs, then builds the `AppLogger` on the returned sink.
///
/// After the first frame, bootstrap calls [recordFileName]: the
/// `currentLogFile` key is for a downgrade only, and a SharedPreferences
/// commit has no place on the cold-start path.
final class LogSession {
  LogSession({
    required this._paths,
    required this._prefs,
    required this._clock,
  });

  final AppPaths _paths;
  final PrefsStore _prefs;
  final Clock _clock;

  /// Session logs older than this many days are deleted (today and the 7
  /// days before are kept).
  static const int keptDays = 7;

  /// The name of the file [open] created; null before.
  String? _fileName;

  /// Creates this launch's log file (and the logs folder) and returns the
  /// sink appending to it. Writes no preference ([recordFileName] does).
  /// Throws a [StorageException] when the file cannot be created.
  Future<FileLogSink> open() async {
    final String name = fileNameFor(_clock.now());
    final File file = File('${_paths.logsDir}/$name');
    try {
      await file.create(recursive: true);
    } on FileSystemException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StorageException('Could not create the log file $name', cause: error),
        stackTrace,
      );
    }
    _fileName = name;
    return FileLogSink.open(file.path);
  }

  /// Names the file [open] created in `currentLogFile`. Call it after the
  /// first frame.
  ///
  /// The app never reads `currentLogFile`; it is written because older
  /// versions append to the file it names, so a downgraded install keeps
  /// logging somewhere sensible. Throws a [StateError] before [open], and a
  /// [StorageException] when the platform refuses the write.
  Future<void> recordFileName() async {
    final String? name = _fileName;
    if (name == null) {
      throw StateError('LogSession.recordFileName() called before open()');
    }
    await _prefs.write(PrefKeys.currentLogFile, name);
  }

  /// Deletes the session logs dated more than [keptDays] calendar days
  /// before today, logging each one. Run it unawaited after start: it never
  /// throws, a failure is logged as a warning.
  ///
  /// Days are compared as calendar dates (DST-safe), and a name that is not
  /// dated is skipped:
  /// - only `.txt` files dated by their `yyyy-MM-dd` prefix count;
  /// - a name containing `videos` is never deleted, whatever its date.
  Future<void> deleteOldLogs({required AppLogger logger}) async {
    final LocalDay today = LocalDay.fromDateTime(_clock.now());
    try {
      await for (final FileSystemEntity entity in Directory(
        _paths.logsDir,
      ).list()) {
        final String name = entity.uri.pathSegments.last;
        if (!_isExpired(name, today: today)) continue;
        await entity.delete();
        logger.info('LOGS', 'Deleted old log file: $name');
      }
    } on FileSystemException catch (error, stackTrace) {
      logger.warning(
        'LOGS',
        'Could not delete old log files',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// `yyyy-MM-dd_HH-mm-ss.txt` for [time] (`DateTime.toString()` without
  /// the fraction, `:` → `-`, ` ` → `_`).
  static String fileNameFor(DateTime time) {
    final DateTime local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${LocalDay.fromDateTime(local).fileStem}_'
        '${two(local.hour)}-${two(local.minute)}-${two(local.second)}.txt';
  }

  static bool _isExpired(String name, {required LocalDay today}) {
    if (!name.endsWith('.txt') || name.contains('videos')) return false;
    final LocalDay? day = LocalDay.tryParseStem(name.split('_').first);
    return day != null && today.epochDay - day.epochDay > keptDays;
  }
}
