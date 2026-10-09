// FilmstripFrames: the frames under the trim window, made from the source
// the editor opened (not a saved clip, so not the ThumbnailRepository),
// one after the other, each reported as soon as it is written, and never
// more than the strip needs.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clip_editor/data/filmstrip_frames.dart';

import '../../../support/support.dart';

void main() {
  late AppPaths paths;
  late FakeThumbnailGateway gateway;
  late FilmstripFrames frames;

  setUp(() async {
    paths = await createTestPaths();
    gateway = FakeThumbnailGateway();
    frames = FilmstripFrames(
      gateway: gateway,
      paths: paths,
      logger: memoryLogger(MemoryLogSink()),
    );
  });

  test('makes frames evenly across the source, each in the middle of its '
      'tile, in the order asked, at the bounds asked, under the editor\'s '
      'cache folder, and deletes them when the editor goes', () async {
    final List<FilmstripFrame> made = await frames
        .of(
          '/src/LONG.mp4',
          durationMs: 6000,
          count: 6,
          width: 90,
          height: 50,
          order: <int>[3, 4, 0],
        )
        .toList();

    expect(
      <int>[for (final FilmstripFrame frame in made) frame.index],
      <int>[3, 4, 0],
    );
    expect(
      <int>[
        for (final ThumbnailRequest request in gateway.requests) request.timeMs,
      ],
      <int>[3500, 4500, 500],
    );
    expect(gateway.requests.first.maxWidth, 90);
    expect(gateway.requests.first.maxHeight, 50);
    for (final FilmstripFrame frame in made) {
      expect(File(frame.path).existsSync(), isTrue);
      expect(frame.path, startsWith('${paths.cacheDir}/filmstrip/'));
    }

    // One frame at the window's start, in the same folder.
    final String? tile = await frames.frameAt(
      '/src/LONG.mp4',
      timeMs: 1200,
      width: 700,
      height: 394,
    );
    expect(tile, startsWith('${paths.cacheDir}/filmstrip/'));

    await frames.dispose();

    for (final String path in <String>[
      for (final FilmstripFrame frame in made) frame.path,
      tile!,
    ]) {
      expect(File(path).existsSync(), isFalse);
    }
  });

  // One tile a second between 10 and 60 s; a
  // shorter source keeps the tiles that fill the strip.
  test('the strip makes the tiles that fill it for a source under 10 s, a '
      'tile a second from 10 to 60 s, and 60 at most', () {
    // (source ms, fitted tiles) -> tiles
    final Map<(int, int), int> table = <(int, int), int>{
      (2000, 4): 4,
      (9999, 5): 5,
      (10000, 5): 10,
      (12400, 5): 12,
      (60000, 20): 60,
      (90000, 30): 60,
    };
    for (final MapEntry<(int, int), int> row in table.entries) {
      expect(
        FilmstripFrames.tileCount(durationMs: row.key.$1, fitted: row.key.$2),
        row.value,
        reason: '${row.key}',
      );
    }
  });

  test('a frame that cannot be made is none, and the strip skips it', () async {
    gateway.failingVideos.add('/src/BROKEN.mp4');

    expect(
      await frames.frameAt('/src/BROKEN.mp4', timeMs: 0, width: 9, height: 5),
      isNull,
    );
    expect(
      await frames
          .of(
            '/src/BROKEN.mp4',
            durationMs: 2000,
            count: 3,
            width: 90,
            height: 50,
          )
          .toList(),
      isEmpty,
    );
  });
}
