// Guards two media-engine rules that no type checker catches:
// - ffmpeg-kit is imported by exactly one file, the gateway, so switching
//   the GPL build for the LGPL one (App Store) is a one-file change;
// - the media core (commands, policies, types) is pure Dart: no Flutter,
//   so it runs and is tested anywhere.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Dart file under [folder], with its path relative to the repo.
Iterable<(String, String)> dartFiles(String folder) sync* {
  final Directory directory = Directory(folder);
  if (!directory.existsSync()) return;
  for (final FileSystemEntity entity in directory.listSync(recursive: true)) {
    final String name = entity.uri.pathSegments.last;
    if (entity is File && name.endsWith('.dart') && !name.startsWith('._')) {
      yield (entity.path, entity.readAsStringSync());
    }
  }
}

void main() {
  test('only the ffmpeg gateway imports ffmpeg-kit', () {
    const String gateway = 'lib/core/platform/ffmpeg_kit_gateway.dart';
    final List<String> importers = <String>[
      for (final (String path, String source) in dartFiles('lib'))
        if (source.contains('package:ffmpeg_kit_flutter_new/')) path,
    ];
    expect(importers.where((String path) => path != gateway), isEmpty);
  });

  test('the media core imports no Flutter', () {
    final RegExp forbidden = RegExp(
      "^import 'package:flutter/",
      multiLine: true,
    );
    final List<String> offenders = <String>[
      for (final String folder in <String>[
        'lib/core/media/commands',
        'lib/core/media/policy',
        'lib/core/media/types',
      ])
        for (final (String path, String source) in dartFiles(folder))
          if (forbidden.hasMatch(source)) path,
    ];
    expect(offenders, isEmpty);
  });
}
