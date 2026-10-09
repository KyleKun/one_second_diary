import 'dart:io';

import 'package:one_second_diary/core/logging/app_logger.dart';

/// The files the in-app camera writes (into its plugin's temp folder).
///
/// A recording the camera page does not keep is deleted at once; a kept one
/// goes to the clip editor, whose save deletes it.
///
/// A plain class (not final), so bloc tests can fake it.
class RecordingTemps {
  RecordingTemps({required this._logger});

  final AppLogger _logger;

  static const String _tag = 'RECORDING';

  /// Whether the recording at [path] has anything in it. The camera can
  /// stop "fine" and leave an empty file (it got no frame): the editor
  /// could only say that it can't play it. One stat, off the UI thread
  /// (the stop handler already awaits the camera).
  Future<bool> hasData(String path) async {
    try {
      return await File(path).length() > 0;
    } on FileSystemException {
      return false;
    }
  }

  /// Deletes the recording at [path]. Never throws: a file that can't be
  /// deleted is logged and left to the system's temp clean-up.
  Future<void> discard(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not delete a recording that was not kept',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
