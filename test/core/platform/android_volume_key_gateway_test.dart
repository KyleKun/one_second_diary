import 'package:flutter_android_volume_keydown/flutter_android_volume_keydown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/android_volume_key_gateway.dart';
import 'package:one_second_diary/core/platform/volume_key_gateway.dart';

void main() {
  test('on Android each volume key press is a shutter press; on iOS nothing '
      'is ever pressed and the plugin is never asked', () async {
    bool asked = false;
    AndroidVolumeKeyGateway gatewayOn({required bool isAndroid}) =>
        AndroidVolumeKeyGateway(
          isAndroid: isAndroid,
          keyPresses: () {
            asked = true;
            return Stream<HardwareButton>.fromIterable(<HardwareButton>[
              HardwareButton.volume_down,
              HardwareButton.volume_up,
            ]);
          },
        );

    expect(await gatewayOn(isAndroid: false).presses().toList(), isEmpty);
    expect(asked, isFalse);

    expect(await gatewayOn(isAndroid: true).presses().toList(), <VolumeKey>[
      VolumeKey.down,
      VolumeKey.up,
    ]);
  });
}
