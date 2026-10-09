import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/theme/osd_fonts.dart';

import 'support/font_manifest.dart';
import 'support/sfnt_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Rubik is the UI and display font of every language but Chinese, so
  // every bundled weight must draw the Latin and Cyrillic letters.
  test(
    'every bundled Rubik weight draws the Latin and Cyrillic letters',
    () async {
      const letters =
          'ŀl·çàèéíïòóúüěščřžýůťďňőűäöüßñ¿¡âæêëîôœùûÿãõ'
          'абвгдеёжзийклмнопрстуфхцчшщъыьэюяіўґєї'
          'АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯІЎҐЄЇ';
      final rubik = (await FontManifest.load()).fontsOf(OsdFonts.rubik);
      expect(rubik, isNotEmpty);
      for (final font in rubik) {
        final mapped = SfntFont(
          await rootBundle.load(font.asset),
        ).mappedCodePoints();
        final missing = letters.runes
            .where((rune) => !mapped.contains(rune))
            .map(String.fromCharCode)
            .join();
        expect(missing, isEmpty, reason: font.asset);
      }
    },
  );
}
