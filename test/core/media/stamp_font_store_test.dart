import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/policy/stamp_font.dart';
import 'package:one_second_diary/core/media/stamp_font_store.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

import '../../support/support.dart';

/// Assets as bytes by key, the way `rootBundle.load` hands them over.
Future<ByteData> Function(String) assets(Map<String, List<int>> bytes) =>
    (String key) async => ByteData.sublistView(
      Uint8List.fromList(bytes[key] ?? (throw StateError('No asset $key'))),
    );

void main() {
  late AppPaths paths;

  setUp(() async {
    paths = await createTestPaths();
  });

  test(
    'copies the font asset to its versioned name in the fonts folder',
    () async {
      final StampFontStore store = StampFontStore(
        paths: paths,
        loadAsset: assets(<String, List<int>>{
          StampFont.yuseiMagic.assetKey: <int>[1, 2, 3],
        }),
      );

      final String path = await store.install(StampFont.yuseiMagic);

      expect(path, '${paths.fontsDir}/YuseiMagic-Regular.v1.ttf');
      expect(File(path).readAsBytesSync(), <int>[1, 2, 3]);
    },
  );

  // The version in the name decides freshness: a copy is made once per
  // version and then reused, without reading the 6 MB asset again.
  test('keeps an existing copy of the same version', () async {
    final File existing = File('${paths.fontsDir}/YuseiMagic-Regular.v1.ttf')
      ..createSync(recursive: true)
      ..writeAsBytesSync(<int>[9, 9]);
    final StampFontStore store = StampFontStore(
      paths: paths,
      loadAsset: assets(<String, List<int>>{}),
    );

    final String path = await store.install(StampFont.yuseiMagic);

    expect(path, existing.path);
    expect(File(path).readAsBytesSync(), <int>[9, 9]);
  });

  // A copy cut short (app killed, disk full) must never sit under the final
  // name: it would be reused forever and draw no stamp.
  test('a failed copy leaves nothing under the versioned name', () async {
    final StampFontStore store = StampFontStore(
      paths: paths,
      loadAsset: (String key) async => throw const FileSystemException('full'),
    );

    await expectLater(
      store.install(StampFont.notoSansSc),
      throwsA(isA<StorageException>()),
    );
    expect(File(StampFont.notoSansSc.pathIn(paths)).existsSync(), isFalse);
  });

  // Older installs left magic.ttf (6 MB) and datestamp_fallback.ttf in the
  // same folder. An older version re-copies a missing font before every
  // stamp, so a downgrade still works.
  test('removes the copies v1.7 made and keeps everything else', () async {
    File file(String name) =>
        File('${paths.fontsDir}/$name')..createSync(recursive: true);
    final List<File> legacy = <File>[
      file('magic.ttf'),
      file('datestamp_fallback.ttf'),
      file('NotoSans-DateStamp.v1.ttf'),
    ];
    final List<File> kept = <File>[
      file('YuseiMagic-Regular.v1.ttf'),
      file('Rubik-Medium.v1.ttf'),
      file('logs.zip'),
    ];
    final StampFontStore store = StampFontStore(
      paths: paths,
      loadAsset: assets(<String, List<int>>{}),
    );

    await store.removeLegacyCopies();

    expect(legacy.where((File f) => f.existsSync()), isEmpty);
    expect(kept.where((File f) => !f.existsSync()), isEmpty);
    // Nothing to remove the second time: no error either.
    await store.removeLegacyCopies();
  });
}
