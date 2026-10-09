import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

import 'support/font_manifest.dart';
import 'support/sfnt_font.dart';

const String _iconFontAsset = 'assets/fonts/MaterialSymbolsRounded-Subset.ttf';

Future<SfntFont> _loadIconFont() async {
  final data = await rootBundle.load(_iconFontAsset);
  return SfntFont(data);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The app draws its icons from a subset font: a glyph missing from the
  // subset shows as a blank box.
  test('the registered subset font holds exactly the OsdIcons glyphs, '
      'named in tool/icons/icons.txt', () async {
    final manifest = await FontManifest.load();
    final mapped = (await _loadIconFont()).mappedCodePoints();
    final listed = <String>{
      for (final line in File('tool/icons/icons.txt').readAsLinesSync())
        if (line.trim().isNotEmpty && !line.trim().startsWith('#'))
          line.trim().split(RegExp(r'\s+')).first,
    };

    expect(manifest.assetsOf(OsdIcons.fontFamily), <String>[_iconFontAsset]);
    expect(
      <String>[
        for (final MapEntry(key: name, value: icon) in OsdIcons.all.entries)
          if (!mapped.contains(icon.codePoint) ||
              icon.fontFamily != OsdIcons.fontFamily ||
              icon.fontPackage != null)
            '$name (0x${icon.codePoint.toRadixString(16)})',
      ],
      isEmpty,
      reason: 'Rebuild the font with tool/icons/subset_icons.py',
    );
    expect(mapped, <int>{
      for (final icon in OsdIcons.all.values) icon.codePoint,
    });
    expect(
      OsdIcons.all.keys.toSet(),
      listed,
      reason: 'Run tool/icons/subset_icons.py after editing icons.txt',
    );
  });

  // The state animations (nav icons, the cup, the check) need the FILL axis
  // to survive the subsetting.
  test('the subset font keeps the FILL, GRAD, opsz and wght axes', () async {
    final font = await _loadIconFont();

    expect(
      font.variationAxes().map((axis) => axis.tag),
      unorderedEquals(<String>['FILL', 'GRAD', 'opsz', 'wght']),
    );
    final fill = font.variationAxes().singleWhere((axis) => axis.tag == 'FILL');
    expect((fill.min, fill.max), (0.0, 1.0));
  });
}
