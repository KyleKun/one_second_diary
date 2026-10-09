import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/stamp_font.dart';
import 'package:one_second_diary/core/media/policy/stamp_font_policy.dart';

void main() {
  StampFont fontOf(List<String> texts, {bool legacy = false}) =>
      StampFontPolicy.forTexts(texts, legacy: legacy);

  test('stamps are Rubik in every Latin and Cyrillic language, and Noto '
      'Sans SC as soon as a character needs it', () {
    for (final String date in <String>[
      '01/10/2026',
      'October 1, 2026',
      '1. října 2026',
      '2026. október 1.',
      '1 октября 2026 г.',
      '1 кастрычніка 2026 г.',
    ]) {
      expect(fontOf(<String>[date]), StampFont.rubik, reason: date);
    }
    expect(fontOf(<String>['2026年10月1日']), StampFont.notoSansSc);
    // One font for the date and the place.
    expect(fontOf(<String>['October 1, 2026', '北京, 中国']), StampFont.notoSansSc);
    expect(fontOf(<String>['October 1, 2026', 'Tokyo\r']), StampFont.rubik);
  });

  test('the legacy preference puts Yusei Magic first, then the same two', () {
    expect(
      fontOf(<String>['October 1, 2026'], legacy: true),
      StampFont.yuseiMagic,
    );
    expect(fontOf(<String>['2026年10月1日'], legacy: true), StampFont.yuseiMagic);
    // Yusei Magic has no Cyrillic and no č or ř.
    expect(
      fontOf(<String>['1 октября 2026 г.'], legacy: true),
      StampFont.rubik,
    );
    expect(fontOf(<String>['1. října 2026'], legacy: true), StampFont.rubik);
    // 删 is in neither Yusei Magic nor Rubik.
    expect(fontOf(<String>['删除'], legacy: true), StampFont.notoSansSc);
  });

  test('when no font draws everything, the one missing the fewest '
      'characters draws the stamps', () {
    // Noto Sans SC lacks ř; Rubik lacks the six Chinese characters. A tie
    // goes to the first font.
    expect(fontOf(<String>['1. října 2026', '北京市朝阳区']), StampFont.notoSansSc);
    expect(fontOf(<String>['1. října 2026', '京']), StampFont.rubik);
  });
}
