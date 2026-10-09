import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/character/domain/character_look.dart';

void main() {
  test('a look round-trips through its stored string, hidden included', () {
    const CharacterLook look = CharacterLook(
      shape: CharacterShape.flower,
      eyes: CharacterEyes.sparkle,
      mouth: CharacterMouth.open,
      color: Color(0xFFB98AD6),
      hidden: true,
    );

    expect(look.encode(), 'flower,sparkle,open,FFB98AD6,hidden');
    expect(CharacterLook.decode(look.encode()), look);
    expect(
      CharacterLook.decode(CharacterLook.defaults.encode()),
      CharacterLook.defaults,
    );
  });

  test('an empty or garbled string reads as the default look', () {
    expect(CharacterLook.decode(''), CharacterLook.defaults);
    expect(CharacterLook.decode('nonsense'), CharacterLook.defaults);
    expect(CharacterLook.decode(',,,,'), CharacterLook.defaults);
  });

  test('a token this version does not know reads as that field\'s default, '
      'the other fields kept', () {
    expect(
      CharacterLook.decode('blob,sleepy,tiny,FF4FB3A9,shown'),
      const CharacterLook(
        eyes: CharacterEyes.sleepy,
        mouth: CharacterMouth.tiny,
        color: Color(0xFF4FB3A9),
      ),
    );
  });

  test('a colour outside the palette reads as the default colour', () {
    expect(
      CharacterLook.decode('round,dots,cat,FF123456,shown'),
      const CharacterLook(
        shape: CharacterShape.round,
        eyes: CharacterEyes.dots,
        mouth: CharacterMouth.cat,
      ),
    );
    expect(
      CharacterLook.decode('round,dots,cat,zzz,shown').color,
      CharacterLook.defaults.color,
    );
  });

  test('a random look is never hidden and only wears palette colours', () {
    final math.Random random = math.Random(7);
    for (int i = 0; i < 50; i++) {
      final CharacterLook look = CharacterLook.random(random);
      expect(look.hidden, isFalse);
      expect(CharacterPalette.colors, contains(look.color));
    }
  });
}
