import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/ffmpeg_color.dart';

void main() {
  // 0xrrggbb, lower case, zeros kept. A plain `toRadixString(16)
  // .substring(2)` would drop colour digits when alpha is below 0x10. A bare
  // 0xRRGGBB (StampStyle.rgb) is read the same way.
  test('the low 24 bits as 0xrrggbb, lower case, six digits whatever the '
      'alpha', () {
    const Map<int, String> cases = <int, String>{
      0xFFE53935: '0xe53935',
      0xFF0A0B0C: '0x0a0b0c',
      0xFF000000: '0x000000',
      0xFFFFFFFF: '0xffffff',
      0xFF0F1133: '0x0f1133',
      0xFF00FF00: '0x00ff00',
      0x0FFFFFFF: '0xffffff',
      0x05FFFFFF: '0xffffff',
      0x0AFFFFFF: '0xffffff',
      0x00FF6366: '0xff6366',
      0x000000FF: '0x0000ff',
    };
    for (final MapEntry<int, String>(:int key, :String value)
        in cases.entries) {
      expect(FfmpegColor.hex(key), value, reason: key.toRadixString(16));
    }
  });
}
