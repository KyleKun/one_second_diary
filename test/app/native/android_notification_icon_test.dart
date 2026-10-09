// Android draws a small icon from its alpha only, and the plugin finds it
// by name at run time: a missing resource fails every reminder, a coloured
// one shows as a white blob.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/di/injection_container.dart';

const String _res = 'android/app/src/main/res';

void main() {
  final RegExpMatch reference = RegExp(
    r'^@drawable/(\w+)$',
  ).firstMatch(reminderSmallIcon)!;
  final String name = reference.group(1)!;

  test('the icon the reminders use is a vector drawable of white shapes '
      'on transparent, and resource shrinking keeps it, although nothing '
      'references it statically', () {
    final File drawable = File('$_res/drawable/$name.xml');
    expect(drawable.existsSync(), isTrue, reason: drawable.path);

    final String xml = drawable.readAsStringSync();
    expect(xml, contains('<vector'));
    final List<String> colours = <String>[
      for (final RegExpMatch match in RegExp(
        'android:(?:fillColor|strokeColor|tint)="([^"]*)"',
      ).allMatches(xml))
        match.group(1)!,
    ];
    expect(colours, isNotEmpty);
    expect(colours, everyElement(anyOf('#FFFFFFFF', '#FFFFFF')));
    expect(
      File('$_res/raw/keep.xml').readAsStringSync(),
      contains('tools:keep="@drawable/$name"'),
    );
  });
}
