import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';

void main() {
  // dateColor 'r,g,b,a' is read as Color.fromARGB(a, r, g, b): an empty or
  // unparsable colour is white, and out-of-range channels wrap (300 is
  // 0x2C).
  test('fromPrefs reads the colour, the format and the outline as v1.7', () {
    const Map<String, int> colours = <String, int>{
      '255,99,102,255': 0xFF6366,
      '0,0,0,255': 0x000000,
      '10,20,30,0': 0x0A141E,
      '': 0xFFFFFF,
      'garbage': 0xFFFFFF,
      '1,2': 0xFFFFFF,
      '255,255,255': 0xFFFFFF,
      'a,b,c,d': 0xFFFFFF,
      '1,2,3,x': 0xFFFFFF,
      '300,0,0,255': 0x2C0000,
      '-1,0,0,255': 0xFF0000,
    };
    for (final MapEntry<String, int>(:String key, :int value)
        in colours.entries) {
      expect(
        StampStyle.fromPrefs(
          dateColor: key,
          dateFormatId: 0,
          dateOutline: true,
        ).rgb,
        value,
        reason: key,
      );
    }

    final StampStyle style = StampStyle.fromPrefs(
      dateColor: '',
      dateFormatId: 1,
      dateOutline: false,
    );
    expect(style.format, StampFormat.written);
    expect(style.outline, isFalse);
  });

  test('toPrefs writes the three v1.7 preferences in their formats, plus '
      'the size token, and round-trips through fromPrefs', () {
    for (final (StampStyle style, _Prefs prefs) in <(StampStyle, _Prefs)>[
      (
        const StampStyle(
          format: StampFormat.written,
          rgb: 0xFF6366,
          outline: false,
        ),
        (
          dateColor: '255,99,102,255',
          dateFormatId: 1,
          dateOutline: false,
          stampSize: 'medium',
        ),
      ),
      (
        const StampStyle(
          format: StampFormat.numeric,
          rgb: 0x0A141E,
          outline: true,
          size: StampSize.large,
        ),
        (
          dateColor: '10,20,30,255',
          dateFormatId: 0,
          dateOutline: true,
          stampSize: 'large',
        ),
      ),
    ]) {
      expect(style.toPrefs(), prefs);
      expect(
        StampStyle.fromPrefs(
          dateColor: prefs.dateColor,
          dateFormatId: prefs.dateFormatId,
          dateOutline: prefs.dateOutline,
          stampSize: prefs.stampSize,
        ),
        style,
      );
    }
  });

  // Medium is the 40 px every clip was burned with, so a style built without a size, or
  // read from an install that never stored `stampSize` (''), is medium; the token is the
  // enum name, and an unknown one (a newer build's) is medium too, never a refusal.
  test('the size is medium unless given; the stampSize token reads back, '
      "'' and an unknown token as medium; the size tells styles apart", () {
    const StampStyle white = StampStyle(
      format: StampFormat.numeric,
      rgb: 0xFFFFFF,
      outline: true,
    );
    expect(white.size, StampSize.medium);
    expect(StampSize.medium.basePx, 40);
    expect(StampSize.small.basePx, 32);
    expect(StampSize.large.basePx, 48);

    const Map<String, StampSize> tokens = <String, StampSize>{
      '': StampSize.medium,
      'small': StampSize.small,
      'medium': StampSize.medium,
      'large': StampSize.large,
      'huge': StampSize.medium,
      'Large': StampSize.medium,
    };
    for (final MapEntry<String, StampSize>(:String key, :StampSize value)
        in tokens.entries) {
      expect(StampSize.fromToken(key), value, reason: "'$key'");
      expect(
        StampStyle.fromPrefs(
          dateColor: '',
          dateFormatId: 0,
          dateOutline: true,
          stampSize: key,
        ).size,
        value,
        reason: "'$key'",
      );
    }
    for (final StampSize size in StampSize.values) {
      expect(StampSize.fromToken(size.token), size);
    }
    expect(
      StampStyle.fromPrefs(dateColor: '', dateFormatId: 0, dateOutline: true),
      white,
      reason: 'an install without the key',
    );
    expect(
      white,
      isNot(
        const StampStyle(
          format: StampFormat.numeric,
          rgb: 0xFFFFFF,
          outline: true,
          size: StampSize.small,
        ),
      ),
    );
  });
}

typedef _Prefs = ({
  String dateColor,
  int dateFormatId,
  bool dateOutline,
  String stampSize,
});
