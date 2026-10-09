import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/bundled_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(rootBundle.clear);

  test('lists the licence text of every bundled font, of the flags and of the '
      'GPL parts of the ffmpeg-kit build the app ships', () async {
    final List<LicenseEntry> entries = await bundledLicenses(
      rootBundle,
    ).toList();

    expect(entries.map((LicenseEntry entry) => entry.packages.single), <String>[
      'Rubik',
      'Yusei Magic',
      'Noto Sans SC',
      'Material Symbols',
      'flag-icons',
      'ffmpeg-kit (full-gpl): FFmpeg, x264, x265, xvidcore, vid.stab',
    ]);
    for (final LicenseEntry entry in entries) {
      expect(
        entry.paragraphs.map((LicenseParagraph p) => p.text).join('\n'),
        anyOf(
          contains('SIL Open Font License'),
          contains('Apache License'),
          contains('MIT License'),
          contains('GNU GENERAL PUBLIC LICENSE'),
        ),
      );
    }
  });
}
