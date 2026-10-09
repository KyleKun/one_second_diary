import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/domain/locale_resolver.dart';

void main() {
  test('a stored supported language wins; otherwise a supported device '
      'language; otherwise English, never the raw code (flips G-2, G-4, '
      'Z-07)', () {
    // An unsupported code handed to intl gives Italian calendar months in an
    // English UI (it) or a crash in the Diary tab (su, jv, yo, ha, eo).
    for (final (String stored, String device, AppLanguage resolved)
        in <(String, String, AppLanguage)>[
          ('fr', 'de', AppLanguage.fr),
          // The device reports pt_BR; its language code is what counts.
          ('', 'pt', AppLanguage.pt),
          ('', 'it', AppLanguage.en),
          ('', 'su', AppLanguage.en),
          ('', 'jv', AppLanguage.en),
          ('', 'yo', AppLanguage.en),
          ('', 'ha', AppLanguage.en),
          ('', 'eo', AppLanguage.en),
          ('', 'fil', AppLanguage.en),
          ('it', 'es', AppLanguage.es),
          ('fil', 'jv', AppLanguage.en),
        ]) {
      expect(
        LocaleResolver.resolve(storedLang: stored, deviceLanguageCode: device),
        resolved,
        reason: 'stored "$stored", device "$device"',
      );
    }
  });
}
