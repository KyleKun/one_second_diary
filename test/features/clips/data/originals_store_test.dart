// The Originals folder sits beside the diary, never inside it: a processed
// import's source keeps its diary-relative path there, a taken name gets
// " (2)", Android gets a .nomedia marker, and nothing is ever deleted
// except by the user. A kept recording takes
// its clip's name with its own extension, and the folder's names alone say
// which clip has a source.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/features/clips/data/originals_store.dart';

import '../../../support/support.dart';
import '../../../support/track_1c/read_only_folder.dart';

void main() {
  late AppPaths paths;
  late FakeMediaStoreGateway gallery;
  late MemoryLogSink sink;

  setUp(() async {
    paths = await createTestPaths();
    gallery = FakeMediaStoreGateway.onDisk(paths);
    sink = MemoryLogSink();
  });

  OriginalsStore store({bool isAndroid = true}) => OriginalsStore(
    paths: paths,
    gateway: gallery,
    logger: memoryLogger(sink),
    isAndroid: isAndroid,
  );

  test('moveIn keeps the diary-relative path beside the diary, adds " (2)" '
      'on a clash, writes .nomedia on Android only, and moveBack returns '
      'the file', () async {
    await seedFile(paths, 'Profiles/Work/2024-01-05.mov');
    final OriginalsStore originals = store();

    final String? first = await originals.moveIn(
      'Profiles/Work/2024-01-05.mov',
    );
    expect(first, 'Profiles/Work/2024-01-05.mov');
    expect(
      File('${paths.originals}Profiles/Work/2024-01-05.mov').existsSync(),
      isTrue,
    );
    expect(
      File(
        paths.absoluteFromVideos('Profiles/Work/2024-01-05.mov'),
      ).existsSync(),
      isFalse,
    );
    expect(File('${paths.originals}${PathNames.noMedia}').existsSync(), isTrue);
    expect(paths.originals.startsWith(paths.videos), isFalse);

    await seedFile(paths, 'Profiles/Work/2024-01-05.mov');
    await seedFile(paths, 'Profiles/Work/2024-01-05.mp4');
    expect(
      await originals.moveIn('Profiles/Work/2024-01-05.mov'),
      'Profiles/Work/2024-01-05 (2).mov',
    );
    expect(
      await originals.moveIn('Profiles/Work/2024-01-05.mp4'),
      'Profiles/Work/2024-01-05.mp4',
    );
    expect(await originals.sizeBytes(), 3 * fakeVideoBytes.length);

    expect(
      await originals.moveBack(
        originalRelPath: 'Profiles/Work/2024-01-05 (2).mov',
        relPath: 'Profiles/Work/2024-01-05.mov',
      ),
      isTrue,
    );
    expect(
      File(
        paths.absoluteFromVideos('Profiles/Work/2024-01-05.mov'),
      ).existsSync(),
      isTrue,
    );

    // iOS: no marker.
    final AppPaths ios = await createTestPaths();
    await seedFile(ios, '2024-01-06.mov');
    final OriginalsStore sandbox = OriginalsStore(
      paths: ios,
      gateway: FakeMediaStoreGateway.onDisk(ios),
      logger: memoryLogger(sink),
      isAndroid: false,
    );
    expect(await sandbox.moveIn('2024-01-06.mov'), '2024-01-06.mov');
    expect(File('${ios.originals}${PathNames.noMedia}').existsSync(), isFalse);
  });

  test('a file the file system will not rename goes through the gallery: '
      'published into the Originals album, then deleted from the diary; a '
      'declined delete keeps the original and takes the copy back', () async {
    final File source = await seedFile(paths, '2024-01-05.mov');
    // Android 11+ refuses to unlink another app's file: the rename fails,
    // the copy works, and the media store delete asks the user.
    if (!makeReadOnly(paths.videos)) {
      markTestSkipped('root can write anywhere');
      return;
    }
    gallery.deleteResults.add(false);

    final String? kept = await store().moveIn('2024-01-05.mov');

    expect(kept, isNull);
    expect(source.existsSync(), isTrue, reason: 'the original stays');
    expect(File('${paths.originals}2024-01-05.mov').existsSync(), isFalse);
    expect(
      gallery.calls.whereType<PublishCall>().single.album,
      PathNames.originalsFolder,
    );
    expect(
      gallery.calls.whereType<DeleteCall>().first.absolutePath,
      source.path,
    );
  });

  test('deleteAll goes through the gateway for every original and leaves '
      'the empty folders gone; a refused file stays', () async {
    await seedFile(paths, 'Profiles/Work/2024-01-05.mov');
    await seedFile(paths, '2024-01-06.mov');
    final OriginalsStore originals = store();
    await originals.moveIn('Profiles/Work/2024-01-05.mov');
    await originals.moveIn('2024-01-06.mov');
    gallery.deleteResults.addAll(<bool>[true, false]);

    expect(await originals.deleteAll(), 1);
    expect(
      gallery.calls.whereType<DeleteCall>().map((DeleteCall c) => c.album),
      unorderedEquals(<String>[
        'OneSecondDiary Originals/Profiles/Work',
        'OneSecondDiary Originals',
      ]),
    );
    expect(await originals.sizeBytes(), fakeVideoBytes.length);
  });

  test('scanNames maps the folder\'s names to the clips they belong to (the '
      'stem with the clip extension; a " (2)" copy, the marker and a stray '
      'file count for nothing), and tells the library; a stale source left '
      'beside a newer one is settled deterministically', () async {
    final OriginalsStore originals = store();
    addTearDown(originals.dispose);
    for (final String name in <String>[
      'Profiles/Work/2024-01-05.mov',
      'Profiles/Work/2024-01-05 (2).mov',
      '2024-01-06-2.mp4',
      'trip/2024-01-07.MOV',
      'notes.txt',
      '2024-01-08.mov',
      '2024-01-08.mp4',
    ]) {
      await File(originals.absoluteOf(name)).create(recursive: true);
    }
    await File(originals.absoluteOf(PathNames.noMedia)).create();
    final List<Set<String>> told = <Set<String>>[];
    final StreamSubscription<Set<String>> sub = originals.sourcesChanged.listen(
      told.add,
    );
    addTearDown(sub.cancel);

    final Set<String> sources = await originals.scanNames();

    expect(sources, <String>{
      'Profiles/Work/2024-01-05.mp4',
      '2024-01-06-2.mp4',
      'trip/2024-01-07.mp4',
      '2024-01-08.mp4',
    });
    expect(originals.sourceRelPaths, sources);
    expect(
      originals.originalRelPathOf('Profiles/Work/2024-01-05.mp4'),
      'Profiles/Work/2024-01-05.mov',
    );
    expect(originals.originalRelPathOf('2024-01-08.mp4'), '2024-01-08.mov');
    expect(
      originals.sourcePathOf('trip/2024-01-07.mp4'),
      originals.absoluteOf('trip/2024-01-07.MOV'),
    );
    expect(originals.sourcePathOf('2024-01-09.mp4'), isNull);
    await pumpEventQueue();
    expect(told, <Set<String>>[sources]);

    // Nothing kept yet: an empty answer, never an error.
    final AppPaths fresh = await createTestPaths();
    final OriginalsStore none = OriginalsStore(
      paths: fresh,
      gateway: FakeMediaStoreGateway.onDisk(fresh),
      logger: memoryLogger(sink),
      isAndroid: true,
    );
    expect(await none.scanNames(), isEmpty);
    expect(
      OriginalsStore.clipRelPathOf('2024-01-05-3.MOV'),
      '2024-01-05-3.mp4',
    );
    expect(OriginalsStore.clipRelPathOf('2024-02-30.mov'), isNull);
    expect(OriginalsStore.clipRelPathOf(PathNames.noMedia), isNull);
  });

  test('keepSource moves a recording under its clip\'s name with its own '
      'extension (a rename: the temp is gone), replaces a stale source of '
      'that clip, invalidates the cached size, and writes the .nomedia '
      'marker once per launch; remove takes a source out again', () async {
    final OriginalsStore originals = store();
    addTearDown(originals.dispose);
    expect(await originals.sizeBytesCached(), 0);
    Future<String> temp(String name, List<int> bytes) async {
      final File file = File('${paths.temporaryDir}/$name');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return file.path;
    }

    final String first = await temp('REC_1.mov', <int>[1, 1]);
    expect(
      await originals.keepSource(
        tempPath: first,
        relPath: 'Profiles/Work/2024-01-05.mp4',
      ),
      'Profiles/Work/2024-01-05.mov',
    );
    expect(File(first).existsSync(), isFalse);
    expect(
      File(
        originals.absoluteOf('Profiles/Work/2024-01-05.mov'),
      ).readAsBytesSync(),
      <int>[1, 1],
    );
    expect(await originals.sizeBytesCached(), 2);
    final File marker = File('${paths.originals}${PathNames.noMedia}');
    expect(marker.existsSync(), isTrue);
    final DateTime markerWritten = marker.lastModifiedSync();

    // The same clip recorded again with another container: one source.
    final String second = await temp('REC_2.mp4', <int>[2, 2, 2]);
    expect(
      await originals.keepSource(
        tempPath: second,
        relPath: 'Profiles/Work/2024-01-05.mp4',
      ),
      'Profiles/Work/2024-01-05.mp4',
    );
    expect(
      File(originals.absoluteOf('Profiles/Work/2024-01-05.mov')).existsSync(),
      isFalse,
    );
    expect(originals.sourceRelPaths, <String>{'Profiles/Work/2024-01-05.mp4'});
    expect(await originals.sizeBytesCached(), 3);
    expect(marker.lastModifiedSync(), markerWritten);
    expect(
      Directory(paths.originals).listSync(recursive: true).whereType<File>(),
      hasLength(2),
      reason: 'the marker and the one source',
    );

    expect(await originals.remove('Profiles/Work/2024-01-05.mp4'), isTrue);
    expect(originals.sourceRelPaths, isEmpty);
    expect(await originals.sizeBytesCached(), 0);
    expect(await originals.remove('Profiles/Work/2024-01-05.mp4'), isTrue);
  });

  test('copySource gives another clip its own copy of a source; '
      'replaceWith puts a remuxed file in a source\'s place; restore brings '
      'a backup back', () async {
    final OriginalsStore originals = store();
    addTearDown(originals.dispose);
    await seedFile(paths, '2024-01-05.mov');
    await originals.moveIn('2024-01-05.mov');

    expect(
      await originals.copySource(
        originalRelPath: '2024-01-05.mov',
        toRelPath: 'Profiles/Work 4K/2024-01-05.mp4',
      ),
      'Profiles/Work 4K/2024-01-05.mov',
    );
    expect(originals.sourceRelPaths, <String>{
      '2024-01-05.mp4',
      'Profiles/Work 4K/2024-01-05.mp4',
    });
    expect(
      File(
        originals.absoluteOf('Profiles/Work 4K/2024-01-05.mov'),
      ).readAsBytesSync(),
      fakeVideoBytes,
    );

    final File remuxed = File('${paths.scratchDir}/privacy/2024-01-05.mov');
    await remuxed.parent.create(recursive: true);
    await remuxed.writeAsBytes(<int>[7]);
    expect(
      await originals.replaceWith(
        originalRelPath: '2024-01-05.mov',
        tempPath: remuxed.path,
      ),
      isTrue,
    );
    expect(
      File(originals.absoluteOf('2024-01-05.mov')).readAsBytesSync(),
      <int>[7],
    );
    expect(remuxed.existsSync(), isFalse);

    final File backup = File('${paths.trashDir}/x/originals/2024-01-05.mov');
    await backup.parent.create(recursive: true);
    await backup.writeAsBytes(<int>[8]);
    await originals.remove('2024-01-05.mov');
    expect(
      await originals.restore(
        backupPath: backup.path,
        originalRelPath: '2024-01-05.mov',
      ),
      isTrue,
    );
    expect(
      File(originals.absoluteOf('2024-01-05.mov')).readAsBytesSync(),
      <int>[8],
    );
    expect(backup.existsSync(), isTrue, reason: 'a copy; the trash drops it');
    expect(originals.sourceRelPaths, contains('2024-01-05.mp4'));
  });

  test(
    'contents counts every original but the marker, with their bytes: '
    'walked once per launch and again after a write here; deleteAll '
    'leaves (0, 0) and tells the library that no clip has a source',
    () async {
      await seedFile(paths, 'Profiles/Work/2024-01-05.mov');
      await seedFile(paths, '2024-01-06.mov', bytes: <int>[1, 2]);
      final OriginalsStore originals = store();
      addTearDown(originals.dispose);
      final List<Set<String>> announced = <Set<String>>[];
      originals.sourcesChanged.listen(announced.add);
      expect(await originals.contentsCached(), (count: 0, bytes: 0));

      await originals.moveIn('Profiles/Work/2024-01-05.mov');
      await originals.moveIn('2024-01-06.mov');

      expect(await originals.contentsCached(), (
        count: 2,
        bytes: fakeVideoBytes.length + 2,
      ), reason: 'the .nomedia marker is not a video');
      expect(await originals.sizeBytesCached(), fakeVideoBytes.length + 2);

      // A file dropped in by hand is not seen until the next write here.
      await File(originals.absoluteOf('stray.mov')).writeAsBytes(<int>[7]);
      expect((await originals.contentsCached()).count, 2);
      expect((await originals.contents()).count, 3);

      expect(await originals.deleteAll(), 3);
      expect(await originals.contentsCached(), (count: 0, bytes: 0));
      expect(originals.sourceRelPaths, isEmpty);
      await pumpEventQueue();
      expect(announced.last, isEmpty, reason: 'hasSource false everywhere');
    },
  );

  test('a .nomedia marker the platform refuses is ONE warning per launch, '
      'with the path and the error, saying the gallery may show the '
      'originals; the moves go on all the same', () async {
    // A folder in the marker's place: File.create() fails on it, as a
    // write by path refused under DCIM on Android 11+ does.
    await Directory(
      '${paths.originals}${PathNames.noMedia}',
    ).create(recursive: true);
    await seedFile(paths, 'Profiles/Work/2024-01-05.mov');
    await seedFile(paths, '2024-01-06.mov');
    final OriginalsStore originals = store();
    addTearDown(originals.dispose);

    expect(
      await originals.moveIn('Profiles/Work/2024-01-05.mov'),
      'Profiles/Work/2024-01-05.mov',
    );
    expect(await originals.moveIn('2024-01-06.mov'), '2024-01-06.mov');

    final List<String> warnings = sink.lines
        .where((String line) => line.contains(PathNames.noMedia))
        .toList();
    expect(warnings, hasLength(1), reason: 'once per launch, not per move');
    expect(warnings.single, startsWith('[WARNING]'));
    expect(
      warnings.single,
      contains(
        '[Originals] Could not write the marker '
        '${paths.originals}${PathNames.noMedia}; the gallery may show the '
        'originals',
      ),
    );
    expect(warnings.single, contains('\nError: FileSystemException'));
  });
}
