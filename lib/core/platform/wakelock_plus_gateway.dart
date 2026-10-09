import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/wakelock_gateway.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// [WakelockGateway] over `wakelock_plus`.
final class WakelockPlusGateway implements WakelockGateway {
  WakelockPlusGateway({required this._logger});

  final AppLogger _logger;

  static const String _tag = 'WAKELOCK';

  @override
  Future<void> enable() => _toggle(on: true);

  @override
  Future<void> disable() => _toggle(on: false);

  /// Best effort, as the interface says: a plugin failure is logged and
  /// never reaches the job that asked.
  Future<void> _toggle({required bool on}) async {
    try {
      await (on ? WakelockPlus.enable() : WakelockPlus.disable());
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not ${on ? 'enable' : 'disable'} the wakelock',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
