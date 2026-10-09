import 'dart:async';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/media_store_gateway.dart';

/// A [MediaStoreGateway] whose calls answer within a time limit: a call still
/// unanswered by then reads as `false` (logged).
///
/// For callers that must finish: the fork never answers some native failures or
/// an allowed consent prompt of the last delete step (see [MediaStoreGateway]).
/// Used for the launch chain and for profile deletion (one consent prompt per
/// file, so give it a limit a person can answer within).
///
/// The call goes on inside the wrapped gateway, so a late answer can still carry
/// the operation out after the caller was told `false`. **Never wrap the gateway
/// of the `MediaPublisher` that saves and replaces clips:** it deletes the render
/// on `false`, and a consent allowed after the limit would delete the old clip
/// with nothing to put in its place.
final class TimeLimitedMediaStoreGateway implements MediaStoreGateway {
  TimeLimitedMediaStoreGateway({
    required this._inner,
    required this._timeLimit,
    required this._logger,
  });

  /// Shared with the gateway it wraps and `MediaPublisher`, so one gallery
  /// write logs under one tag.
  static const String _tag = 'MediaGallery';

  final MediaStoreGateway _inner;
  final Duration _timeLimit;
  final AppLogger _logger;

  @override
  Future<bool> publish({required String tempFilePath, required String album}) =>
      _limited(
        'publishing ${_nameOf(tempFilePath)} into $album',
        _inner.publish(tempFilePath: tempFilePath, album: album),
      );

  @override
  Future<bool> delete({required String absolutePath, required String album}) =>
      _limited(
        'deleting ${_nameOf(absolutePath)} from $album',
        _inner.delete(absolutePath: absolutePath, album: album),
      );

  @override
  Future<bool> requestWrite(List<String> absolutePaths) => _limited(
    'asking to write ${absolutePaths.length} file(s)',
    _inner.requestWrite(absolutePaths),
  );

  Future<bool> _limited(String description, Future<bool> call) async {
    try {
      return await call.timeout(_timeLimit);
    } on TimeoutException {
      _logger.error(
        _tag,
        'No answer within ${_timeLimit.inSeconds} s $description; reported '
        'as not done',
      );
      return false;
    }
  }

  static String _nameOf(String path) =>
      path.substring(path.lastIndexOf('/') + 1);
}
