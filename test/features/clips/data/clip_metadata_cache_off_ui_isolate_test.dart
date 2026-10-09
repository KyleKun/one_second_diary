// Perf guard: the clip metadata cache reads, decodes, encodes and writes
// its sidecar off the calling isolate.
// See clip_scan_off_ui_isolate_test.dart for how the IOOverrides guard
// works. The logger's sink cannot be sent to another isolate, as in the
// app, so a background closure that captured the cache would fail too.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/unsendable_log_sink.dart';

void main() {
  test('loading and flushing 5 000 entries touch no file on the calling '
      'isolate', () async {
    final AppPaths paths = await createTestPaths();
    final UnsendableLogSink sink = UnsendableLogSink();
    final ClipMetadataCache cache = ClipMetadataCache(
      paths: paths,
      logger: memoryLogger(sink),
    );
    for (int i = 0; i < 5000; i++) {
      cache.put(
        relPath: 'trip/$i.mp4',
        stamp: FileStamp(sizeBytes: i, modifiedMs: i),
        meta: ClipMeta(durationMs: i, subtitleText: 'clip $i'),
      );
    }
    final List<String> touched = <String>[];
    Never record(String what) {
      touched.add(what);
      throw StateError('file system touched on the calling isolate: $what');
    }

    final ClipMetadataCache reloaded = ClipMetadataCache(
      paths: paths,
      logger: memoryLogger(sink),
    );
    await IOOverrides.runZoned(
      () async {
        await cache.flush();
        await reloaded.load();
      },
      createDirectory: (String path) => record('Directory($path)'),
      createFile: (String path) => record('File($path)'),
      stat: (String path) => record('stat($path)'),
      statSync: (String path) => record('statSync($path)'),
      fseGetType: (String path, bool followLinks) => record('type($path)'),
      fseGetTypeSync: (String path, bool followLinks) =>
          record('typeSync($path)'),
    );

    expect(touched, isEmpty);
    expect(sink.lines, isEmpty);
    expect(
      reloaded.lookup(
        relPath: 'trip/4999.mp4',
        stamp: const FileStamp(sizeBytes: 4999, modifiedMs: 4999),
      ),
      const ClipMeta(durationMs: 4999, subtitleText: 'clip 4999'),
    );
  });
}
