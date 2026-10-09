import 'dart:convert';

import 'package:flutter/services.dart';

/// One font file of a family, as declared in `pubspec.yaml`.
typedef FontManifestAsset = ({String asset, int? weight});

/// The fonts `pubspec.yaml` registers, read from the bundled `FontManifest.json`.
class FontManifest {
  const FontManifest._(this._families);

  final Map<String, List<FontManifestAsset>> _families;

  static Future<FontManifest> load() async {
    final json =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<Object?>;
    return FontManifest._(<String, List<FontManifestAsset>>{
      for (final family in json.cast<Map<String, Object?>>())
        family['family']! as String: <FontManifestAsset>[
          for (final font
              in (family['fonts']! as List<Object?>)
                  .cast<Map<String, Object?>>())
            (asset: font['asset']! as String, weight: font['weight'] as int?),
        ],
    });
  }

  /// The families in the manifest.
  Iterable<String> get families => _families.keys;

  /// The files of [family], in declaration order.
  List<FontManifestAsset> fontsOf(String family) =>
      _families[family] ?? const <FontManifestAsset>[];

  /// The asset paths of [family], in declaration order.
  List<String> assetsOf(String family) => <String>[
    for (final font in fontsOf(family)) font.asset,
  ];
}
