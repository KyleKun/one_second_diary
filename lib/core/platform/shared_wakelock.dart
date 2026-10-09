import 'package:one_second_diary/core/platform/wakelock_gateway.dart';

/// The screen kept on by whoever needs it, the app's only
/// [WakelockGateway]: the movie job while a movie is made, the movie player
/// while a movie plays, the clip editor while it saves, the camera while it
/// shows, the folder migration. Each [enable] is one hold and each
/// [disable] gives one back; the screen may sleep again only once nobody
/// holds it, so one owner letting go never lets the phone sleep while
/// another needs it on.
///
/// The platform's gateway (`wakelock_plus`) is its private delegate,
/// registered under `DiNames.platformWakelock`. Best effort, like the
/// gateway: never throws.
class SharedWakelock implements WakelockGateway {
  SharedWakelock({required this._platform});

  final WakelockGateway _platform;
  int _holds = 0;

  @override
  Future<void> enable() async {
    _holds++;
    if (_holds == 1) await _platform.enable();
  }

  @override
  Future<void> disable() async {
    if (_holds == 0) return;
    _holds--;
    if (_holds == 0) await _platform.disable();
  }
}
