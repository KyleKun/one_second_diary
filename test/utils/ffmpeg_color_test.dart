import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/utils/ffmpeg_color.dart';

void main() {
  group('hex', () {
    test('drops the alpha of an opaque color', () {
      expect(FFmpegColor.hex(const Color(0xffffffff)), '0xffffff');
      expect(FFmpegColor.hex(const Color(0xffe53935)), '0xe53935');
    });

    test('pads dark colors to six digits', () {
      expect(FFmpegColor.hex(const Color(0xff000000)), '0x000000');
      expect(FFmpegColor.hex(const Color(0xff00000f)), '0x00000f');
    });

    test('handles colors whose alpha is below 0x10', () {
      expect(FFmpegColor.hex(const Color(0x00000000)), '0x000000');
      expect(FFmpegColor.hex(const Color(0x0000ff00)), '0x00ff00');
      expect(FFmpegColor.hex(const Color(0x0fffffff)), '0xffffff');
    });
  });
}
