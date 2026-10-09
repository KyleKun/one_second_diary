import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/thumbnail_gateway.dart';

/// [ThumbnailGateway] over `get_thumbnail_video`, the app's only thumbnail
/// plugin (a second one crashes iOS with a duplicate key).
///
/// - Always a JPEG FILE at the exact [writeThumbnail] path: the plugin
///   writes it natively, so no image bytes cross the platform channel.
/// - Both bounds are passed on: Android only uses its scaled decoder
///   (`getScaledFrameAtTime`, API 27+) when both are set; with one of them 0
///   it decodes the full 1920×1080 frame and scales afterwards.
/// - The parent folder is created first: neither platform does it.
/// - The written path is ours, not the plugin's answer: iOS answers with a
///   percent-encoded URL path.
final class GetThumbnailVideoGateway implements ThumbnailGateway {
  GetThumbnailVideoGateway({required this._logger});

  final AppLogger _logger;

  static const String _tag = 'THUMBNAILS';

  @override
  Future<String?> writeThumbnail({
    required String videoPath,
    required String outputPath,
    required int maxWidth,
    required int maxHeight,
    required int quality,
    required int timeMs,
  }) async {
    if (!outputPath.endsWith('.jpg')) {
      throw ArgumentError.value(outputPath, 'outputPath', 'must end in .jpg');
    }
    try {
      await File(outputPath).parent.create(recursive: true);
      await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: outputPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
        timeMs: timeMs,
      );
      return outputPath;
    } on PlatformException catch (error, stackTrace) {
      _logFailure(videoPath, error, stackTrace);
    } on FileSystemException catch (error, stackTrace) {
      _logFailure(videoPath, error, stackTrace);
    }
    return null;
  }

  void _logFailure(String videoPath, Object error, StackTrace stackTrace) =>
      _logger.warning(
        _tag,
        'No frame from $videoPath',
        error: error,
        stackTrace: stackTrace,
      );
}
