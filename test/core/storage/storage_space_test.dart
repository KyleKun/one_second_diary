// When the phone fills up while a clip or a movie is made, ffmpeg says so in
// its log, the file system with ENOSPC (28 on Android and iOS), the
// gallery's copy as the cause of its refusal.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/storage/storage_space.dart';

void main() {
  test('tells running out of space from any other failure', () {
    final Map<String, (Object, bool)> rows = <String, (Object, bool)>{
      'ffmpeg writing the movie': (
        const VideoProcessingException(
          'concat failed',
          returnCode: 1,
          logTail: 'av_interleaved_write_frame(): No space left on device',
        ),
        true,
      ),
      'a file the app wrote, by its error code': (
        const FileSystemException(
          'Cannot write',
          '/scratch/videos.txt',
          OSError('', 28),
        ),
        true,
      ),
      'a file the app wrote, by its message': (
        const FileSystemException(
          'Cannot copy',
          '/movies/x.mp4',
          OSError('No space left on device'),
        ),
        true,
      ),
      "the gallery's copy, through the cause it gives": (
        MediaStoreException(
          'Could not publish the movie',
          cause: PlatformException(
            code: 'copy',
            message: 'ENOSPC (No space left on device)',
          ),
        ),
        true,
      ),
      'another ffmpeg failure': (
        const VideoProcessingException(
          'concat failed',
          returnCode: 1,
          logTail: 'Invalid data found when processing input',
        ),
        false,
      ),
      'another file system error': (
        const FileSystemException('Cannot open', '/x', OSError('', 2)),
        false,
      ),
      'anything else': (StateError('boom'), false),
    };

    for (final MapEntry<String, (Object, bool)> row in rows.entries) {
      final (Object error, bool outOfSpace) = row.value;
      expect(StorageSpace.isOutOfSpace(error), outOfSpace, reason: row.key);
    }
  });
}
