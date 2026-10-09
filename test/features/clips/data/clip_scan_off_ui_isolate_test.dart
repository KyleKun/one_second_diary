// Perf guard: the scan of a 5 000-clip temp tree runs off the UI isolate.
//
// `IOOverrides` are zone values of the CURRENT isolate. Inside the zone
// below, any `Directory`, `File` or stat the scanner created on the calling
// isolate (the UI isolate in the app) is recorded; the background isolate
// the scan must run in never sees the overrides. So the guard is exact, not
// a timing heuristic: a synchronous `listSync` on the UI isolate would fail
// it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_scan.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/unsendable_log_sink.dart';

const int _clips = 5000;

void main() {
  test('scanning a $_clips-clip tree touches no file on the calling '
      'isolate', () async {
    final AppPaths paths = await createTestPaths();
    final LocalDay first = LocalDay(2012, 1, 1);
    for (int i = 0; i < _clips; i++) {
      // Every tenth clip sits in a user-made sub-folder.
      final String folder = i % 10 == 0
          ? '${paths.videos}trip${i % 7}/'
          : paths.videos;
      final File file = File(
        '$folder${ClipNameCodec.format(first.addDays(i))}',
      );
      if (i % 10 == 0) file.parent.createSync(recursive: true);
      file.writeAsBytesSync(fakeVideoBytes);
    }
    final ClipScanner scanner = ClipScanner(
      paths: paths,
      logger: memoryLogger(UnsendableLogSink()),
    );
    final List<String> touched = <String>[];

    Never record(String what) {
      touched.add(what);
      throw StateError('file system touched on the calling isolate: $what');
    }

    final ClipScan scan = await IOOverrides.runZoned(
      () => scanner.scan(ProfileKey.defaultProfile),
      createDirectory: (String path) => record('Directory($path)'),
      createFile: (String path) => record('File($path)'),
      createLink: (String path) => record('Link($path)'),
      stat: (String path) => record('stat($path)'),
      statSync: (String path) => record('statSync($path)'),
      fseGetType: (String path, bool followLinks) => record('type($path)'),
      fseGetTypeSync: (String path, bool followLinks) =>
          record('typeSync($path)'),
    );

    expect(touched, isEmpty);
    expect(scan.index.clipCount, _clips);
    expect(scan.index.firstDay, first);
  });
}
