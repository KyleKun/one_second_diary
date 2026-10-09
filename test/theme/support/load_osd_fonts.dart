import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'font_manifest.dart';

/// Loads every font family `pubspec.yaml` registers (Rubik, Magic, Material
/// Symbols Rounded, …) into the test engine, so text and icons render with the
/// real glyphs instead of the test font. Call it from `setUpAll`.
Future<void> loadOsdFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest = await FontManifest.load();
  for (final family in manifest.families) {
    final loader = FontLoader(family);
    for (final asset in manifest.assetsOf(family)) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}
