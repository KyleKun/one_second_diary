import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/locked_folder.dart';

const FileStamp _stamp = FileStamp(sizeBytes: 1234, modifiedMs: 1700000000000);

const ClipMeta _full = ClipMeta(
  durationMs: 2500,
  hasAudio: true,
  hasSubtitleStream: true,
  subtitleText: 'Walk around Asakusa\nbefore the rain — 雨',
  locationText: 'Tokyo, Japan',
  latitude: 35.71,
  longitude: 139.79,
  isOsdV15: true,
  width: 1920,
  height: 1080,
  codec: 'h264',
  origin: ClipOrigin.galleryPhoto,
);

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
  });

  ClipMetadataCache newCache() =>
      ClipMetadataCache(paths: paths, logger: memoryLogger(sink));

  test('a written entry survives a reload, for the same file stamp only; no '
      'sidecar yet (first launch) is an empty cache, silently', () async {
    final ClipMetadataCache first = newCache();
    await first.load();
    expect(first.lookup(relPath: 'trip/2024-01-05.mp4', stamp: _stamp), isNull);
    expect(sink.lines, isEmpty);

    await newCache().write(
      relPath: 'trip/2024-01-05.mp4',
      stamp: _stamp,
      meta: _full,
    );

    final ClipMetadataCache reloaded = newCache();
    await reloaded.load();

    expect(
      reloaded.lookup(relPath: 'trip/2024-01-05.mp4', stamp: _stamp),
      _full,
    );
    expect(
      reloaded.lookup(
        relPath: 'trip/2024-01-05.mp4',
        stamp: const FileStamp(sizeBytes: 1234, modifiedMs: 1700000000001),
      ),
      isNull,
    );
    expect(
      reloaded.lookup(
        relPath: 'trip/2024-01-05.mp4',
        stamp: const FileStamp(sizeBytes: 1235, modifiedMs: 1700000000000),
      ),
      isNull,
    );
    expect(reloaded.lookup(relPath: '2024-01-05.mp4', stamp: _stamp), isNull);
  });

  test(
    'recentPlaces lists each place once (trimmed, without case, the first '
    'casing kept), most used first then by name, private clips left out',
    () async {
      final ClipMetadataCache cache = newCache();
      int n = 0;
      void put(String place, {bool private = false}) => cache.put(
        relPath: '2024-01-${(++n).toString().padLeft(2, '0')}.mp4',
        stamp: _stamp,
        meta: ClipMeta(locationText: place, isPrivate: private),
      );
      put('Tokyo, Japan');
      put('Home');
      put(' tokyo, japan ');
      put('');
      put('   ');
      put('Beach', private: true);
      put('Alps');
      put('HOME', private: true);

      expect(cache.recentPlaces(), <({String place, int count})>[
        (place: 'Tokyo, Japan', count: 2),
        (place: 'Alps', count: 1),
        (place: 'Home', count: 1),
      ]);
      expect(newCache().recentPlaces(), isEmpty);
    },
  );

  test('the sidecar sits in the support index folder and holds no absolute '
      'path (invariant 17); a corrupt sidecar is logged, ignored and replaced '
      'on the next write', () async {
    final ClipMetadataCache cache = newCache();
    await cache.write(
      relPath: 'Profiles/Work/2024-01-05-2.mp4',
      stamp: _stamp,
      meta: _full,
    );

    final File sidecar = File(
      '${paths.supportIndexDir}/${ClipMetadataCache.fileName}',
    );
    expect(ClipMetadataCache.fileName, 'clip_meta_v1.json');
    final String json = await sidecar.readAsString();
    expect(json, contains('"Profiles/Work/2024-01-05-2.mp4"'));
    expect(json, isNot(contains(paths.videos)));
    expect(json, isNot(contains(paths.internal)));
    expect(json, isNot(contains('"/')));

    // A corrupt sidecar is logged, ignored and replaced on the next write.
    {
      final File sidecar = File(
        '${paths.supportIndexDir}/${ClipMetadataCache.fileName}',
      );
      await sidecar.parent.create(recursive: true);
      await sidecar.writeAsString('{"version": 1, "clips": [truncated');
      final ClipMetadataCache cache = newCache();

      await cache.load();
      await cache.write(relPath: '2024-01-05.mp4', stamp: _stamp, meta: _full);

      expect(
        sink.lines,
        contains(
          allOf(
            startsWith('[WARNING] '),
            contains('[CLIP_META] Ignored an unreadable clip metadata cache'),
          ),
        ),
      );
      final ClipMetadataCache reloaded = newCache();
      await reloaded.load();
      expect(reloaded.lookup(relPath: '2024-01-05.mp4', stamp: _stamp), _full);
    }
  });

  group('put and remove stay in memory until a flush', () {
    const ClipMeta short = ClipMeta(durationMs: 1000);

    Future<ClipMetadataCache> reloaded() async {
      final ClipMetadataCache cache = newCache();
      await cache.load();
      return cache;
    }

    test('a flush persists every change so far; concurrent writes all reach '
        'the disk, the newest state last', () async {
      final ClipMetadataCache cache = newCache();
      cache
        ..put(relPath: '2024-01-01.mp4', stamp: _stamp, meta: short)
        ..put(relPath: '2024-01-02.mp4', stamp: _stamp, meta: _full);
      expect(cache.lookup(relPath: '2024-01-01.mp4', stamp: _stamp), short);
      expect(
        (await reloaded()).lookup(relPath: '2024-01-01.mp4', stamp: _stamp),
        isNull,
      );

      await cache.flush();
      cache.remove('2024-01-01.mp4');
      await cache.flush();

      final ClipMetadataCache later = await reloaded();
      expect(later.lookup(relPath: '2024-01-01.mp4', stamp: _stamp), isNull);
      expect(later.lookup(relPath: '2024-01-02.mp4', stamp: _stamp), _full);

      // Concurrent writes all reach the disk, the newest state last.
      {
        final ClipMetadataCache cache = newCache();

        await Future.wait(<Future<void>>[
          for (int day = 1; day <= 9; day++)
            cache.write(
              relPath: '2024-01-0$day.mp4',
              stamp: _stamp,
              meta: short,
            ),
        ]);

        final ClipMetadataCache later = await reloaded();
        for (int day = 1; day <= 9; day++) {
          expect(
            later.lookup(relPath: '2024-01-0$day.mp4', stamp: _stamp),
            short,
          );
        }
      }
    });
  });

  test('a save that fails is logged, never thrown, and retried by the next '
      'flush', () async {
    final Directory index = Directory(paths.supportIndexDir);
    await index.create(recursive: true);
    if (!await lockFolder(index.path, mode: '555')) return;
    final ClipMetadataCache cache = newCache();

    await cache.write(relPath: '2024-01-05.mp4', stamp: _stamp, meta: _full);
    expect(
      sink.lines,
      contains(
        allOf(
          startsWith('[ERROR] '),
          contains('[CLIP_META] Could not save the clip metadata cache'),
        ),
      ),
    );

    await Process.run('chmod', <String>['755', index.path]);
    await cache.flush();
    final ClipMetadataCache reloaded = newCache();
    await reloaded.load();
    expect(reloaded.lookup(relPath: '2024-01-05.mp4', stamp: _stamp), _full);
  });

  // The library mirrors the tags the cache holds (LibraryWiring): it must
  // hear of every change, and only of changes.
  test("tells each clip's tags when they differ from what it held, [] when "
      'the clip is deleted, and nothing for the same tags again; it knows '
      'at launch which clips carry tags', () async {
    final ClipMetadataCache cache = newCache();
    final List<({String relPath, List<String> tags})> told =
        <({String relPath, List<String> tags})>[];
    final StreamSubscription<({String relPath, List<String> tags})> listening =
        cache.tagChanges.listen(told.add);
    addTearDown(listening.cancel);
    const ClipMeta tagged = ClipMeta(
      durationMs: 1000,
      tags: <String>['bread', 'trip'],
    );
    const FileStamp rewritten = FileStamp(
      sizeBytes: 1235,
      modifiedMs: 1700000000001,
    );

    cache
      ..put(relPath: '2024-01-01.mp4', stamp: _stamp, meta: tagged)
      ..put(relPath: '2024-01-01.mp4', stamp: rewritten, meta: tagged)
      ..put(relPath: '2024-01-02.mp4', stamp: _stamp, meta: _full)
      ..put(
        relPath: '2024-01-03.mp4',
        stamp: _stamp,
        meta: const ClipMeta(tags: <String>[]),
      );
    await pumpEventQueue();

    expect(told, hasLength(1));
    expect(told.single.relPath, '2024-01-01.mp4');
    expect(told.single.tags, <String>['bread', 'trip']);
    expect(cache.tagsByRelPath, <String, List<String>>{
      '2024-01-01.mp4': <String>['bread', 'trip'],
    });

    cache
      ..put(
        relPath: '2024-01-01.mp4',
        stamp: rewritten,
        meta: const ClipMeta(durationMs: 1000, tags: <String>['trip']),
      )
      ..put(
        relPath: '2024-01-02.mp4',
        stamp: _stamp,
        meta: const ClipMeta(tags: <String>['kids']),
      )
      ..remove('2024-01-02.mp4')
      ..remove('2024-01-03.mp4');
    await pumpEventQueue();

    expect(
      told
          .skip(1)
          .map((({String relPath, List<String> tags}) t) => t.relPath)
          .toList(),
      <String>['2024-01-01.mp4', '2024-01-02.mp4', '2024-01-02.mp4'],
    );
    expect(
      told
          .skip(1)
          .map((({String relPath, List<String> tags}) t) => t.tags)
          .toList(),
      <List<String>>[
        <String>['trip'],
        <String>['kids'],
        <String>[],
      ],
    );
    expect(cache.tagsByRelPath, <String, List<String>>{
      '2024-01-01.mp4': <String>['trip'],
    });
  });
}
