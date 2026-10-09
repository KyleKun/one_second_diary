import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';

/// Whether the phone ran out of space: a clip save and a movie (after its
/// space check: iOS never answers the check, and other apps write too) both
/// ask it of their failure.
abstract final class StorageSpace {
  /// ENOSPC, "No space left on device", on Android and iOS alike.
  static const int _noSpaceCode = 28;

  /// How ffmpeg, the file system and the gallery's copy say it.
  static const List<String> _noSpaceWords = <String>[
    'No space left on device',
    'ENOSPC',
  ];

  /// Whether [error] ended the work because the phone filled up: ffmpeg's
  /// log, a file the app wrote, or the cause the gallery gives for refusing
  /// a copy.
  static bool isOutOfSpace(Object error) => switch (error) {
    FileSystemException(:final OSError? osError)
        when osError?.errorCode == _noSpaceCode =>
      true,
    VideoProcessingException(:final String logTail)
        when _saysNoSpace(logTail) =>
      true,
    AppException(:final Object cause) => isOutOfSpace(cause),
    _ => _saysNoSpace(error.toString()),
  };

  static bool _saysNoSpace(String text) =>
      _noSpaceWords.any((String words) => text.contains(words));
}
