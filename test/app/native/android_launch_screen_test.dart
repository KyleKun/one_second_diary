// The launch window can only follow the phone's dark mode (the `night`
// resource qualifier), not the app's own theme: an install whose app theme
// differs from the phone's sees the phone's colour until the first frame.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/theme/osd_colors.dart';

const String _res = 'android/app/src/main/res';

String _read(String path) => File(path).readAsStringSync();

/// `#RRGGBB` of [color], as Android resources spell it.
String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}'
        .toUpperCase();

/// The value of the resource `<[type] name="[name]">` in [file].
String? _resource(String file, {required String type, required String name}) =>
    RegExp(
      '<$type\\s+name="${RegExp.escape(name)}"\\s*>([^<]*)</$type>',
    ).firstMatch(_read(file))?.group(1)?.trim();

/// The `<style name="[name]" …>…</style>` element in [file].
String? _style(String file, String name) => RegExp(
  '<style\\s+name="${RegExp.escape(name)}"[^>]*?(/>|>.*?</style>)',
  dotAll: true,
).firstMatch(_read(file))?.group(0);

/// The `<item name="android:[attribute]">` value inside [style].
String? _item(String style, String attribute) => RegExp(
  '<item\\s+name="android:${RegExp.escape(attribute)}"[^>]*>([^<]*)</item>',
).firstMatch(style)?.group(1)?.trim();

/// The parent of the style [name] in [file].
String? _parentOf(String file, String name) =>
    RegExp('parent="([^"]+)"').firstMatch(_style(file, name) ?? '')?.group(1);

/// [attribute] of style [name], looked up through its parents in [file]
/// and `values/styles.xml`, the way Android resolves it.
String? _resolved(String file, String name, String attribute) {
  final Set<String> seen = <String>{};
  String? next = name;
  while (next != null && seen.add(next)) {
    final String style = next;
    next = null;
    for (final String source in <String>{file, '$_res/values/styles.xml'}) {
      final String? element = _style(source, style);
      if (element == null) continue;
      final String? value = _item(element, attribute);
      if (value != null) return value;
      next = _parentOf(source, style);
      break;
    }
  }
  return null;
}

/// The name of [folder], a child of [_res].
String _nameOf(FileSystemEntity folder) =>
    folder.uri.pathSegments.reversed.skip(1).first;

void main() {
  test("the launch colour is the BG token of the phone's theme, with system "
      'bar icons that read on it; the navigation bar takes it only where its '
      'icons can turn dark (API 27+)', () {
    String? value(String folder, String type, String name) =>
        _resource('$_res/$folder/${type}s.xml', type: type, name: name);

    expect(
      value('values', 'color', 'osd_launch_background'),
      _hex(OsdColors.light.bg),
    );
    expect(
      value('values-night', 'color', 'osd_launch_background'),
      _hex(OsdColors.dark.bg),
    );
    // Dark icons on the light launch colour, light icons on the dark one.
    expect(value('values', 'bool', 'osd_launch_light_bars'), 'true');
    expect(value('values-night', 'bool', 'osd_launch_light_bars'), 'false');
    // Android 8.0 has no light navigation bar: it stays black by day.
    expect(value('values', 'color', 'osd_launch_navigation_bar'), '#000000');
    for (final String folder in <String>['values-v27', 'values-night']) {
      expect(
        value(folder, 'color', 'osd_launch_navigation_bar'),
        '@color/osd_launch_background',
        reason: folder,
      );
    }
  });

  test('every launch window paints the launch colour with the app logo: '
      "the launch drawable, Android 12+'s own splash and the window behind "
      'Flutter; no night style hides the Android 12+ splash', () {
    final String icon = RegExp(
      '<application[^>]*android:icon="([^"]+)"',
      dotAll: true,
    ).firstMatch(_read('android/app/src/main/AndroidManifest.xml'))!.group(1)!;
    final List<File> drawables = <File>[
      for (final FileSystemEntity folder in Directory(_res).listSync())
        if (folder is Directory && _nameOf(folder).startsWith('drawable'))
          File('${folder.path}/launch_background.xml'),
    ].where((File file) => file.existsSync()).toList();
    expect(drawables, isNotEmpty);
    for (final File drawable in drawables) {
      final String text = drawable.readAsStringSync();
      expect(
        text,
        contains('<item android:drawable="@color/osd_launch_background"'),
        reason: drawable.path,
      );
      expect(
        RegExp(
          '<bitmap[^>]*android:gravity="center"[^>]*'
          'android:src="${RegExp.escape(icon)}"',
        ).hasMatch(text),
        isTrue,
        reason: '${drawable.path} shows $icon, the app icon, centred',
      );
    }

    const String styles = '$_res/values/styles.xml';
    const String v31 = '$_res/values-v31/styles.xml';
    for (final (String file, String attribute, String value)
        in <(String, String, String)>[
          (styles, 'windowBackground', '@drawable/launch_background'),
          (styles, 'windowDrawsSystemBarBackgrounds', 'true'),
          (styles, 'statusBarColor', '@color/osd_launch_background'),
          (styles, 'navigationBarColor', '@color/osd_launch_navigation_bar'),
          (styles, 'windowLightStatusBar', '@bool/osd_launch_light_bars'),
          (styles, 'windowLightNavigationBar', '@bool/osd_launch_light_bars'),
          (v31, 'windowBackground', '@drawable/launch_background'),
          (v31, 'windowLightStatusBar', '@bool/osd_launch_light_bars'),
          (v31, 'windowSplashScreenBackground', '@color/osd_launch_background'),
          (
            v31,
            'windowSplashScreenIconBackgroundColor',
            '@color/osd_launch_background',
          ),
        ]) {
      expect(
        _resolved(file, 'LaunchTheme', attribute),
        value,
        reason: '$file $attribute',
      );
    }
    expect(
      _resolved(styles, 'NormalTheme', 'windowBackground'),
      '@color/osd_launch_background',
    );
    // values-night outranks values-v31: a night style would hide the
    // Android 12+ splash style.
    for (final FileSystemEntity folder in Directory(_res).listSync()) {
      if (folder is! Directory || !_nameOf(folder).contains('night')) continue;
      expect(
        File('${folder.path}/styles.xml').existsSync(),
        isFalse,
        reason: '${_nameOf(folder)}/styles.xml',
      );
    }
  });
}
