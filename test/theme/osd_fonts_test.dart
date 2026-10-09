import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/theme/osd_fonts.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The licence page must show the licence of every font the app bundles.
  test(
    'every bundled font family has its licence text in the bundle',
    () async {
      final licensed = OsdFonts.licenses
          .map((license) => license.family)
          .toSet();

      expect(
        licensed,
        containsAll(<String>[
          OsdFonts.rubik,
          OsdFonts.magic,
          OsdFonts.notoSansSc,
          OsdIcons.fontFamily,
        ]),
      );
      for (final license in OsdFonts.licenses) {
        final text = await rootBundle.loadString(license.asset);
        expect(text, contains(license.kind), reason: license.asset);
      }
    },
  );
}
