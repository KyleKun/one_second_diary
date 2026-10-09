import 'dart:ui';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/share_gateway.dart';
import 'package:share_plus/share_plus.dart';

/// [ShareGateway] over `share_plus`.
final class SharePlusGateway implements ShareGateway {
  /// Bootstrap passes `SharePlus.instance`.
  SharePlusGateway({required this._sharePlus, required this._logger});

  final SharePlus _sharePlus;
  final AppLogger _logger;

  static const String _tag = 'SHARE';

  @override
  Future<void> shareFiles(List<String> paths, {Rect? origin}) => _share(
    ShareParams(
      files: <XFile>[for (final String path in paths) XFile(path)],
      sharePositionOrigin: origin,
    ),
    what: '${paths.length} file(s)',
  );

  @override
  Future<void> shareText(String text, {Rect? origin}) => _share(
    ShareParams(text: text, sharePositionOrigin: origin),
    what: 'text',
  );

  /// Fire-and-forget, as the interface says: a sheet that cannot open is
  /// logged, never thrown into the screen that asked.
  Future<void> _share(ShareParams params, {required String what}) async {
    try {
      await _sharePlus.share(params);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not share $what',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
