// The launch colour is a named colour of the asset catalog with a dark
// appearance, so the launch storyboard needs no image of its own; it has no
// logo, because the app icon cannot be drawn by a launch storyboard without
// an image asset of its own.
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/theme/osd_colors.dart';

const String _colorName = 'LaunchBackground';
const String _colorSet =
    'ios/Runner/Assets.xcassets/$_colorName.colorset/Contents.json';
const String _storyboard = 'ios/Runner/Base.lproj/LaunchScreen.storyboard';

/// The colour an asset catalog entry spells: components as `0xNN` or as
/// fractions of 1.
Color _colorOf(Map<String, Object?> entry) {
  final Map<String, Object?> color = entry['color']! as Map<String, Object?>;
  expect(color['color-space'], 'srgb');
  final Map<String, Object?> components =
      color['components']! as Map<String, Object?>;
  int channel(String name) {
    final String value = components[name]! as String;
    return value.startsWith('0x')
        ? int.parse(value.substring(2), radix: 16)
        : (double.parse(value) * 255).round();
  }

  return Color.fromARGB(
    channel('alpha'),
    channel('red'),
    channel('green'),
    channel('blue'),
  );
}

/// The appearance an asset catalog entry is for: null for any, else the
/// luminosity it names.
String? _appearanceOf(Map<String, Object?> entry) {
  final List<Object?>? appearances = entry['appearances'] as List<Object?>?;
  if (appearances == null) return null;
  final Map<String, Object?> appearance =
      appearances.single! as Map<String, Object?>;
  expect(appearance['appearance'], 'luminosity');
  return appearance['value']! as String;
}

void main() {
  test('the launch storyboard fills the screen with the launch colour, the '
      'BG token: light, and dark in dark mode', () {
    final Map<String, Object?> set =
        jsonDecode(File(_colorSet).readAsStringSync()) as Map<String, Object?>;
    final Map<String?, Color> byAppearance = <String?, Color>{
      for (final Object? entry in set['colors']! as List<Object?>)
        _appearanceOf(entry! as Map<String, Object?>): _colorOf(
          entry as Map<String, Object?>,
        ),
    };

    expect(byAppearance, <String?, Color>{
      null: OsdColors.light.bg,
      'dark': OsdColors.dark.bg,
    });

    final String storyboard = File(_storyboard).readAsStringSync();
    final String view = RegExp(
      '<view key="view"[^>]*>.*?</view>',
      dotAll: true,
    ).firstMatch(storyboard)!.group(0)!;

    // The screen's own background, not one of its sub-views'.
    final String ownBackground = view.replaceAll(
      RegExp('<subviews>.*?</subviews>', dotAll: true),
      '',
    );
    expect(
      ownBackground,
      contains('<color key="backgroundColor" name="$_colorName"/>'),
    );
    expect(
      storyboard,
      contains('<capability name="Named colors" minToolsVersion="9.0"/>'),
    );
    expect(storyboard, contains('<namedColor name="$_colorName">'));
  });
}
