import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/url_gateway.dart';
import 'package:url_launcher/url_launcher.dart';

/// [UrlGateway] over `url_launcher`, always in another app
/// (`LaunchMode.externalApplication`: the browser, the mail app, the store).
final class UrlLauncherGateway implements UrlGateway {
  UrlLauncherGateway({required this._logger});

  final AppLogger _logger;

  /// Never throws: the plugin throws a `PlatformException` for some
  /// failures and answers false for others; both read as false here, and
  /// are logged without the query (a `mailto:` body is user text).
  @override
  Future<bool> open(Uri uri) async {
    final String target = '${uri.scheme} link ${uri.host}'.trim();
    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) _logger.warning('LINKS', 'Nothing could open the $target');
      return opened;
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'LINKS',
        'Could not open the $target',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
