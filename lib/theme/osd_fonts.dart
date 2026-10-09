import 'package:one_second_diary/theme/osd_icons.dart';

/// A bundled font's licence text, to show under Settings › About › Licenses.
///
/// [name] is the heading on the licence page, [asset] the bundled text and
/// [kind] the licence it contains.
typedef OsdFontLicense = ({
  String family,
  String name,
  String asset,
  String kind,
});

/// The font families `pubspec.yaml` registers.
///
/// Nothing is fetched at runtime: the app is offline. Chinese UI text falls
/// back to the platform's system fonts.
abstract final class OsdFonts {
  /// Every UI and display style, and the stamps: static Rubik 400, 500, 600
  /// and 700.
  static const String rubik = 'Rubik';

  /// The stamp font behind the "legacy font" preference (`StampFontPolicy`):
  /// Yusei Magic 400.
  static const String magic = 'Magic';

  /// The stamps Rubik can't draw (Chinese): ffmpeg burns them in this
  /// file, and the stamp styles preview them in it. Noto Sans SC 500.
  static const String notoSansSc = 'NotoSansSC';

  static const String _ofl = 'SIL Open Font License';

  /// The licence of every bundled font. Bootstrap registers them with
  /// `LicenseRegistry.addLicense`.
  static const List<OsdFontLicense> licenses = <OsdFontLicense>[
    (
      family: rubik,
      name: 'Rubik',
      asset: 'assets/fonts/Rubik-OFL.txt',
      kind: _ofl,
    ),
    (
      family: magic,
      name: 'Yusei Magic',
      asset: 'assets/fonts/YuseiMagic-OFL.txt',
      kind: _ofl,
    ),
    (
      family: notoSansSc,
      name: 'Noto Sans SC',
      asset: 'assets/fonts/NotoSansSC-OFL.txt',
      kind: _ofl,
    ),
    (
      family: OsdIcons.fontFamily,
      name: 'Material Symbols',
      asset: 'assets/fonts/MaterialSymbols-LICENSE.txt',
      kind: 'Apache License',
    ),
  ];
}
