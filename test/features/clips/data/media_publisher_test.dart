import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/domain/undo_token.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/scripted_media_store_gateway.dart';

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late ScriptedMediaStoreGateway gateway;
  late MediaPublisher publisher;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    gateway = ScriptedMediaStoreGateway.onDisk(paths);
    publisher = MediaPublisher(
      gateway: gateway,
      paths: paths,
      logger: memoryLogger(sink),
      clock: FakeClock(DateTime(2024, 1, 5, 10)),
    );
  });

  /// A finished render in scratch, as the media engine leaves it.
  Future<String> render(String name, {List<int> bytes = const <int>[1]}) async {
    final File file = File('${paths.scratchDir}/job/$name');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  group('publish', () {
    test('creates the destination folder, gives the temp the destination '
        'name first (Android publishes under the temp file name) and moves it '
        'into the album of its destination; Undo deletes it again, naming its '
        'album; a refused publish returns null, discards the temp and is '
        'logged; publish never throws', () async {
      gateway.strictFolders = true;
      final String temp = await render('2024-01-05.mp4', bytes: <int>[7]);

      final UndoToken? token = await publisher.publish(
        tempPath: temp,
        relPath: 'Profiles/Gone/2024-01-05-2.mp4',
      );

      expect(token, isNotNull);
      expect(gateway.calls, <MediaStoreCall>[
        PublishCall(
          tempFilePath: '${paths.scratchDir}/job/2024-01-05-2.mp4',
          album: 'OneSecondDiary/Profiles/Gone',
        ),
      ]);
      final String clip = paths.absoluteFromVideos(
        'Profiles/Gone/2024-01-05-2.mp4',
      );
      expect(await File(clip).readAsBytes(), <int>[7]);
      expect(File(temp).existsSync(), isFalse);

      expect(await publisher.undo(token!), isTrue);
      expect(File(clip).existsSync(), isFalse);
      expect(
        gateway.calls.last,
        DeleteCall(absolutePath: clip, album: 'OneSecondDiary/Profiles/Gone'),
      );

      // A refused publish.
      {
        gateway.publishResults.add(false);
        final String temp = await render('2024-01-05.mp4');

        final UndoToken? token = await publisher.publish(
          tempPath: temp,
          relPath: '2024-01-05.mp4',
        );

        expect(token, isNull);
        expect(File(temp).existsSync(), isFalse);
        expect(
          File(paths.absoluteFromVideos('2024-01-05.mp4')).existsSync(),
          isFalse,
        );
        expect(
          sink.lines.single,
          startsWith(
            '[ERROR] 2024-01-05 10:00:00.000: [MediaGallery] Could not '
            'publish 2024-01-05.mp4 into OneSecondDiary',
          ),
        );

        // Never throws: a temp that cannot be moved is logged as a failure.
        expect(
          await publisher.publish(
            tempPath: '${paths.scratchDir}/job/missing.mp4',
            relPath: '2024-01-05.mp4',
          ),
          isNull,
        );
        expect(sink.lines.last, contains('Could not publish 2024-01-05.mp4'));
      }
    });

    test(
      'names the album on every call, so nothing carries over from the '
      'previous write (Z MP-08: after My movies, a clip went to Movies/)',
      () async {
        await publisher.publish(
          tempPath: await render('OSD-Movie-1-2024-01-05.mp4'),
          relPath: 'Movies/OSD-Movie-1-2024-01-05.mp4',
        );
        await publisher.publish(
          tempPath: await render('2024-01-05.mp4'),
          relPath: '2024-01-05.mp4',
        );

        expect(
          <String>[
            for (final MediaStoreCall call in gateway.calls)
              (call as PublishCall).album,
          ],
          <String>['OneSecondDiary/Movies', 'OneSecondDiary'],
        );
      },
    );
  });

  // media_store_plus can answer true with the file somewhere else: from
  // Android 10, an insert whose name exists on disk without a MediaStore row
  // (a clip written by path) gets a unique name, "… (1).mp4"; below
  // Android 10 it copies to a hard-coded DCIM path. The diary would keep
  // showing the old clip while the new one sits elsewhere.
  group('a publish reported done but not at its destination', () {
    late MediaPublisher misplacing;

    setUp(() {
      misplacing = MediaPublisher(
        gateway: _UniqueNamingGateway(paths),
        paths: paths,
        logger: memoryLogger(sink),
        clock: FakeClock(DateTime(2024, 1, 5, 10)),
      );
    });

    test('is a failure, never a clip; in a replace the old clip stays and '
        'nothing is committed', () async {
      final UndoToken? token = await misplacing.publish(
        tempPath: await render('2024-01-05.mp4', bytes: <int>[7, 7]),
        relPath: '2024-01-05.mp4',
      );

      expect(token, isNull);
      expect(
        File(paths.absoluteFromVideos('2024-01-05.mp4')).existsSync(),
        isFalse,
      );
      expect(
        sink.lines,
        contains(
          allOf(startsWith('[ERROR]'), contains('not at its destination')),
        ),
      );

      // In a replace, it keeps the old clip and commits nothing.
      await seedFile(paths, '2024-01-06.mp4', bytes: <int>[1]);
      final UndoToken? replaced = await misplacing.replace(
        tempPath: await render('2024-01-06.mp4', bytes: <int>[7, 7]),
        relPath: '2024-01-06.mp4',
      );

      expect(replaced, isNull);
      expect(
        await File(paths.absoluteFromVideos('2024-01-06.mp4')).readAsBytes(),
        <int>[1],
      );
      expect(await _filesUnder(paths.trashDir), isEmpty);
    });
  });

  group('replace', () {
    test('publishes the new clip over the old one, which stays in place '
        'while the new one is published (invariant 13); Undo puts the old clip '
        'back', () async {
      await seedFile(paths, 'Profiles/Work/2024-01-05.mp4', bytes: <int>[1]);
      final UndoToken token = (await publisher.replace(
        tempPath: await render('2024-01-05.mp4', bytes: <int>[2]),
        relPath: 'Profiles/Work/2024-01-05.mp4',
      ))!;

      expect(
        await File(
          paths.absoluteFromVideos('Profiles/Work/2024-01-05.mp4'),
        ).readAsBytes(),
        <int>[2],
      );
      expect(token, isA<ReplacedUndo>());

      final bool undone = await publisher.undo(token);

      expect(undone, isTrue);
      expect(
        await File(
          paths.absoluteFromVideos('Profiles/Work/2024-01-05.mp4'),
        ).readAsBytes(),
        <int>[1],
      );
      expect(
        gateway.calls.last,
        isA<PublishCall>().having(
          (PublishCall call) => call.album,
          'album',
          'OneSecondDiary/Profiles/Work',
        ),
      );

      // The old clip is still in place while the new one is published.
      {
        await seedFile(paths, '2024-01-05.mp4', bytes: <int>[1]);
        final List<List<int>> seenAtPublish = <List<int>>[];
        gateway.beforePublish = (String temp, String album) =>
            seenAtPublish.add(
              File(
                paths.absoluteFromVideos('2024-01-05.mp4'),
              ).readAsBytesSync(),
            );

        await publisher.replace(
          tempPath: await render('2024-01-05.mp4', bytes: <int>[2]),
          relPath: '2024-01-05.mp4',
        );

        expect(seenAtPublish, <List<int>>[
          <int>[1],
        ]);
      }
    });

    test(
      'a refused publish keeps the old clip and leaves no trash (Android '
      'asks for consent for clips from before a reinstall), even when the '
      'platform lost it before refusing; a refused Undo keeps the backup',
      () async {
        await seedFile(paths, '2024-01-05.mp4', bytes: <int>[1]);
        gateway.publishResults.add(false);

        final UndoToken? token = await publisher.replace(
          tempPath: await render('2024-01-05.mp4', bytes: <int>[2]),
          relPath: '2024-01-05.mp4',
        );

        expect(token, isNull);
        expect(
          await File(paths.absoluteFromVideos('2024-01-05.mp4')).readAsBytes(),
          <int>[1],
        );
        expect(await _filesUnder(paths.trashDir), isEmpty);
        expect(await _filesUnder(paths.scratchDir), isEmpty);

        // When the platform lost the old clip before refusing, the backup
        // goes back.
        gateway
          ..loseExistingOnRefusal = true
          ..publishResults.add(false);
        expect(
          await publisher.replace(
            tempPath: await render('2024-01-05.mp4', bytes: <int>[2]),
            relPath: '2024-01-05.mp4',
          ),
          isNull,
        );
        expect(
          await File(paths.absoluteFromVideos('2024-01-05.mp4')).readAsBytes(),
          <int>[1],
        );
        expect(await _filesUnder(paths.trashDir), isEmpty);

        // A refused Undo keeps the backup, so it can be tried again.
        {
          await seedFile(paths, '2024-01-05.mp4', bytes: <int>[1]);
          final UndoToken token = (await publisher.replace(
            tempPath: await render('2024-01-05.mp4', bytes: <int>[2]),
            relPath: '2024-01-05.mp4',
          ))!;
          gateway.publishResults.add(false);

          expect(await publisher.undo(token), isFalse);
          expect(await publisher.undo(token), isTrue);
          expect(
            await File(
              paths.absoluteFromVideos('2024-01-05.mp4'),
            ).readAsBytes(),
            <int>[1],
          );
        }
      },
    );
  });

  group('delete', () {
    test(
      'deletes through the gateway, naming the clip album; Undo puts the '
      'clip back, but never over a clip saved under that name since',
      () async {
        final File clip = await seedFile(
          paths,
          'Profiles/Work/2024-01-05.mp4',
          bytes: <int>[1],
        );

        final UndoToken? token = await publisher.delete(
          'Profiles/Work/2024-01-05.mp4',
        );

        expect(token, isA<DeletedUndo>());
        expect(gateway.calls, <MediaStoreCall>[
          DeleteCall(
            absolutePath: clip.path,
            album: 'OneSecondDiary/Profiles/Work',
          ),
        ]);
        expect(clip.existsSync(), isFalse);

        expect(await publisher.undo(token!), isTrue);
        expect(
          await File(
            paths.absoluteFromVideos('Profiles/Work/2024-01-05.mp4'),
          ).readAsBytes(),
          <int>[1],
        );
        expect(await _filesUnder(paths.trashDir), isEmpty);

        // Undo never overwrites a clip saved under that name since.
        {
          await seedFile(paths, '2024-01-05.mp4', bytes: <int>[1]);
          final UndoToken token = (await publisher.delete('2024-01-05.mp4'))!;
          // A new recording of the day takes the free bare name.
          await publisher.publish(
            tempPath: await render('2024-01-05.mp4', bytes: <int>[3]),
            relPath: '2024-01-05.mp4',
          );

          expect(await publisher.undo(token), isFalse);
          expect(
            await File(
              paths.absoluteFromVideos('2024-01-05.mp4'),
            ).readAsBytes(),
            <int>[3],
          );
        }
      },
    );

    test('a refused delete keeps the clip and leaves no trash; with no room '
        'for a backup it deletes without Undo', () async {
      final File clip = await seedFile(paths, '2024-01-05.mp4');
      gateway.deleteResults.add(false);

      final UndoToken? token = await publisher.delete('2024-01-05.mp4');

      expect(token, isNull);
      expect(clip.existsSync(), isTrue);
      expect(await _filesUnder(paths.trashDir), isEmpty);

      // Without room for a backup (storage full) it still deletes, but
      // without Undo.
      final Directory trash = Directory(paths.trashDir);
      if (trash.existsSync()) await trash.delete(recursive: true);
      await File(paths.trashDir).create(recursive: true); // blocks the folder
      final UndoToken? full = await publisher.delete('2024-01-05.mp4');
      expect(clip.existsSync(), isFalse);
      expect(full!.canUndo, isFalse);
      expect(await publisher.undo(full), isFalse);
    });
  });

  group('trash', () {
    test(
      'purging a token (the snackbar was dismissed) empties its backup',
      () async {
        await seedFile(paths, '2024-01-05.mp4', bytes: <int>[1]);
        final UndoToken token = (await publisher.replace(
          tempPath: await render('2024-01-05.mp4', bytes: <int>[2]),
          relPath: '2024-01-05.mp4',
        ))!;

        await publisher.purge(token);

        expect(await _filesUnder(paths.trashDir), isEmpty);
        expect(await publisher.undo(token), isFalse);
        expect(
          await File(paths.absoluteFromVideos('2024-01-05.mp4')).readAsBytes(),
          <int>[2],
        );
      },
    );

    test('the next launch empties the trash of finished writes, and never '
        'throws on an unreadable trash', () async {
      await seedFile(paths, '2024-01-05.mp4', bytes: <int>[1]);
      await seedFile(paths, '2024-01-06.mp4', bytes: <int>[1]);
      await publisher.replace(
        tempPath: await render('2024-01-05.mp4', bytes: <int>[2]),
        relPath: '2024-01-05.mp4',
      );
      await publisher.delete('2024-01-06.mp4');

      final MediaPublisher nextLaunch = MediaPublisher(
        gateway: gateway,
        paths: paths,
        logger: memoryLogger(sink),
        clock: FakeClock(DateTime(2024, 1, 6, 8)),
      );
      await nextLaunch.purgeTrash();

      expect(await _filesUnder(paths.trashDir), isEmpty);
      expect(
        await File(paths.absoluteFromVideos('2024-01-05.mp4')).readAsBytes(),
        <int>[2],
      );
      expect(
        File(paths.absoluteFromVideos('2024-01-06.mp4')).existsSync(),
        isFalse,
      );

      // The launch purge never throws: an unreadable trash is logged.
      await Directory(paths.trashDir).delete(recursive: true);
      await File(paths.trashDir).create(recursive: true); // not a folder
      await nextLaunch.purgeTrash();
      expect(sink.lines.last, contains('Could not read the trash'));
    });

    test('the next launch restores a backup whose replace never finished '
        '(killed after Android removed the old clip)', () async {
      await seedFile(paths, '2024-01-05.mp4', bytes: <int>[1]);
      final Completer<void> killed = Completer<void>();
      gateway
        ..hangPublishes = true
        ..beforePublish = (String temp, String album) {
          File(paths.absoluteFromVideos('2024-01-05.mp4')).deleteSync();
          killed.complete();
        };
      unawaited(
        publisher.replace(
          tempPath: await render('2024-01-05.mp4', bytes: <int>[2]),
          relPath: '2024-01-05.mp4',
        ),
      );
      await killed.future;

      gateway
        ..hangPublishes = false
        ..beforePublish = null;
      final MediaPublisher nextLaunch = MediaPublisher(
        gateway: gateway,
        paths: paths,
        logger: memoryLogger(sink),
        clock: FakeClock(DateTime(2024, 1, 6, 8)),
      );
      await nextLaunch.purgeTrash();

      expect(
        await File(paths.absoluteFromVideos('2024-01-05.mp4')).readAsBytes(),
        <int>[1],
      );
      expect(await _filesUnder(paths.trashDir), isEmpty);
    });
  });
}

/// Every file below [folder] (none when it does not exist).
Future<List<String>> _filesUnder(String folder) async {
  final Directory directory = Directory(folder);
  if (!directory.existsSync()) return const <String>[];
  return <String>[
    await for (final FileSystemEntity entity in directory.list(recursive: true))
      if (entity is File) entity.path,
  ];
}

/// Publishes like Android when the name is taken on disk but not in the
/// MediaStore: the file lands as `<name> (1).mp4` and the call says true.
class _UniqueNamingGateway extends FakeMediaStoreGateway {
  _UniqueNamingGateway(super.paths) : super.onDisk();

  @override
  Future<bool> publish({
    required String tempFilePath,
    required String album,
  }) async {
    calls.add(PublishCall(tempFilePath: tempFilePath, album: album));
    final String name = tempFilePath.substring(
      tempFilePath.lastIndexOf('/') + 1,
    );
    final Directory folder = Directory('$mediaRoot/$album');
    await folder.create(recursive: true);
    await File(
      tempFilePath,
    ).rename('${folder.path}/${name.replaceFirst('.mp4', ' (1).mp4')}');
    return true;
  }
}
