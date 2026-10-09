import 'package:flutter/services.dart';
import 'package:one_second_diary/core/platform/screen_orientation_gateway.dart';

/// [ScreenOrientationGateway] over `SystemChrome.setPreferredOrientations`.
final class SystemChromeOrientationGateway implements ScreenOrientationGateway {
  const SystemChromeOrientationGateway();

  @override
  Future<void> portraitOnly() => SystemChrome.setPreferredOrientations(
    const <DeviceOrientation>[DeviceOrientation.portraitUp],
  );

  @override
  Future<void> allowLandscape() =>
      SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
}
