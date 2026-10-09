import 'package:flutter_android_volume_keydown/flutter_android_volume_keydown.dart';
import 'package:one_second_diary/core/platform/volume_key_gateway.dart';

/// [VolumeKeyGateway] over `flutter_android_volume_keydown` (MainActivity
/// extends its `FlutterAndroidVolumeKeydownActivity`).
final class AndroidVolumeKeyGateway implements VolumeKeyGateway {
  /// [keyPresses] defaults to the plugin's stream; it is only read on
  /// Android ([isAndroid]).
  AndroidVolumeKeyGateway({
    required this._isAndroid,
    Stream<HardwareButton> Function()? keyPresses,
  }) : _keyPresses = keyPresses ?? (() => FlutterAndroidVolumeKeydown.stream);

  final bool _isAndroid;
  final Stream<HardwareButton> Function() _keyPresses;

  @override
  Stream<VolumeKey> presses() {
    if (!_isAndroid) return const Stream<VolumeKey>.empty();
    return _keyPresses().map(
      (HardwareButton button) => switch (button) {
        HardwareButton.volume_up => VolumeKey.up,
        HardwareButton.volume_down => VolumeKey.down,
      },
    );
  }
}
