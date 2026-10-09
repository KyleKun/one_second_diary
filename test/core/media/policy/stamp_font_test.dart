import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/stamp_font.dart';
import 'package:one_second_diary/core/media/stamp_font_store.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

import '../../../theme/support/sfnt_font.dart';

void main() {
  // Older installs hold copies named magic.ttf and datestamp_fallback.ttf
  // that are never refreshed; a versioned name makes the app copy the
  // current asset there. The path goes into a drawtext filter: none of
  // : , ' \ [ ] ; or spaces in the name.
  test("never reuses v1.7's never-refreshed file names", () {
    final AppPaths paths = AppPaths.forTest(Directory('/root'));
    expect(StampFont.rubik.pathIn(paths), '/root/internal/Rubik-Medium.v1.ttf');
    expect(
      StampFont.yuseiMagic.pathIn(paths),
      '/root/internal/YuseiMagic-Regular.v1.ttf',
    );
    expect(
      StampFont.notoSansSc.pathIn(paths),
      '/root/internal/NotoSansSC-Medium.v1.otf',
    );
    for (final StampFont font in StampFont.values) {
      expect(StampFontStore.legacyFileNames, isNot(contains(font.fileName)));
      expect(font.fileName, matches(RegExp(r'^[A-Za-z0-9._-]+$')));
    }
  });

  // Guard: changing a bundled font without bumping its fileName version
  // would leave existing installs on the old copy forever.
  test('each bundled font matches the version in its file name', () {
    const Map<StampFont, String> pinned = <StampFont, String>{
      StampFont.rubik: 'Rubik-Medium.v1.ttf=458163566',
      StampFont.yuseiMagic: 'YuseiMagic-Regular.v1.ttf=690694830',
      StampFont.notoSansSc: 'NotoSansSC-Medium.v1.otf=4199132188',
    };
    for (final StampFont font in StampFont.values) {
      final int checksum = fnv1a32(File(font.assetKey).readAsBytesSync());
      expect(
        '${font.fileName}=$checksum',
        pinned[font],
        reason:
            '${font.assetKey} changed: bump the version in its fileName, '
            'pin the new checksum here and run '
            'tool/fonts/make_stamp_coverage.py.',
      );
    }
  });

  // The policy picks the font from this table: it must be the file's.
  test('the generated coverage of each font is its cmap', () {
    for (final StampFont font in StampFont.values) {
      final Set<int> mapped = SfntFont(
        File(font.assetKey).readAsBytesSync().buffer.asByteData(),
      ).mappedCodePoints();
      for (final int codePoint in <int>[
        ...'Aa0/.,ěčřőűЖяіў年月日删京あ한α'.runes,
        0x20,
        0x7F,
        0x3000,
      ]) {
        expect(
          font.draws(codePoint),
          mapped.contains(codePoint),
          reason: '${font.name} U+${codePoint.toRadixString(16)}',
        );
      }
    }
  });
}

/// FNV-1a, 32 bits: enough to notice a changed font file.
int fnv1a32(List<int> bytes) {
  int hash = 0x811C9DC5;
  for (final int byte in bytes) {
    hash = ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
