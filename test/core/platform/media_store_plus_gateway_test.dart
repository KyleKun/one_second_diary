import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_store_plus/media_store_platform_interface.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:one_second_diary/core/platform/media_store_plus_gateway.dart';
import 'package:one_second_diary/core/platform/sandbox_media_store_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../support/support.dart';
import '../../support/track_1d/fake_media_store_platform.dart';

void main() {
  late AppPaths paths;
  late MemoryLogSink log;
  late FakeMediaStorePlatform platform;

  setUp(() async {
    paths = await createTestPaths();
    log = MemoryLogSink();
    final MediaStorePlatform original = MediaStorePlatform.instance;
    final String originalAppFolder = MediaStore.appFolder;
    platform = FakeMediaStorePlatform();
    MediaStorePlatform.instance = platform;
    addTearDown(() {
      MediaStorePlatform.instance = original;
      MediaStore.appFolder = originalAppFolder;
    });
  });

  SandboxMediaStoreGateway byPath() =>
      SandboxMediaStoreGateway(paths: paths, logger: memoryLogger(log));

  Future<MediaStorePlusGateway> readyGateway() async {
    final MediaStorePlusGateway gateway = MediaStorePlusGateway(
      byPath: byPath(),
      mediaStore: MediaStore.new,
      logger: memoryLogger(log),
    );
    // Let the plugin's constructor learn the SDK level.
    await Future<void>.delayed(Duration.zero);
    return gateway;
  }

  Future<File> tempFile(String name) async {
    final File file = File('${paths.scratchDir}/job/$name');
    await file.parent.create(recursive: true);
    await file.writeAsString('new');
    return file;
  }

  // The app root builds this gateway in the first frame, and `MediaStore()`
  // asks the platform for its SDK level without waiting for it; until the
  // answer lands, the plugin takes the Android 9 path (a plain copy into
  // /storage/emulated/0/DCIM).
  test('makes the plugin on its first call, once, and a publish right after '
      'start-up waits for the SDK level, so Android 10+ always goes through '
      'the media store', () async {
    int made = 0;
    final MediaStorePlusGateway gateway = MediaStorePlusGateway(
      byPath: byPath(),
      mediaStore: () {
        made++;
        return MediaStore();
      },
      logger: memoryLogger(log),
    );
    expect(made, 0);

    expect(
      await gateway.publish(
        tempFilePath: (await tempFile('2024-01-05.mp4')).path,
        album: 'OneSecondDiary',
      ),
      isTrue,
    );
    await gateway.publish(
      tempFilePath: (await tempFile('2024-01-06.mp4')).path,
      album: 'OneSecondDiary',
    );

    expect(made, 1);
    expect(platform.calls, hasLength(2));
    expect(platform.calls, everyElement(startsWith('saveFile ')));
  });

  test('publish saves the temp file as a DCIM video of the album given with '
      'each call (never the one a previous call left in the plugin) and '
      'removes the temp; a temp already gone or that cannot be removed '
      'never fails it', () async {
    final MediaStorePlusGateway gateway = await readyGateway();
    MediaStore.appFolder = 'OneSecondDiary/Movies';
    final File temp = await tempFile('2024-01-05.mp4');

    expect(
      await gateway.publish(
        tempFilePath: temp.path,
        album: 'OneSecondDiary/Profiles/Work',
      ),
      isTrue,
    );
    expect(platform.calls, <String>[
      'saveFile ${temp.path} as 2024-01-05.mp4 in '
          'DCIM/OneSecondDiary/Profiles/Work (video)',
    ]);
    expect(temp.existsSync(), isFalse);

    platform.removesTempOnSave = true;
    expect(
      await gateway.publish(
        tempFilePath: (await tempFile('2024-01-06.mp4')).path,
        album: 'OneSecondDiary',
      ),
      isTrue,
    );
    expect(platform.calls.last, contains(' in DCIM/OneSecondDiary '));
    expect(log.lines, isEmpty);

    // A folder where the temp file was: unlink fails, not "not found".
    platform.removesTempOnSave = false;
    final Directory unremovable = Directory(
      '${paths.scratchDir}/2024-01-07.mp4',
    );
    await unremovable.create(recursive: true);
    expect(
      await gateway.publish(
        tempFilePath: unremovable.path,
        album: 'OneSecondDiary',
      ),
      isTrue,
    );
    expect(
      log.lines.single,
      startsWith(
        '[WARNING] 2024-01-05 10:00:00.000: [MediaGallery] Published '
        '2024-01-07.mp4 but could not remove its temp file',
      ),
    );
  });

  test('a refused save, or a plugin error, is a logged false that keeps the '
      'temp file, never a throw', () async {
    final MediaStorePlusGateway gateway = await readyGateway();
    final File temp = await tempFile('2024-01-05.mp4');

    platform.saveResult = false;
    expect(
      await gateway.publish(tempFilePath: temp.path, album: 'OneSecondDiary'),
      isFalse,
    );
    expect(temp.existsSync(), isTrue);
    expect(log.lines, <String>[
      '[ERROR] 2024-01-05 10:00:00.000: [MediaGallery] MediaStore refused to '
          'save 2024-01-05.mp4 into OneSecondDiary',
    ]);

    platform.saveError = PlatformException(code: 'saveFile');
    expect(
      await gateway.publish(tempFilePath: temp.path, album: 'OneSecondDiary'),
      isFalse,
    );
    expect(temp.existsSync(), isTrue);
    expect(
      log.lines.last,
      startsWith(
        '[ERROR] 2024-01-05 10:00:00.000: [MediaGallery] Could not publish '
        '2024-01-05.mp4 into OneSecondDiary\nError: PlatformException',
      ),
    );
  });

  // Below Android 10 the fork copies to a hard-coded /storage/emulated/0,
  // which a secondary user, a work profile or Secure Folder can't write:
  // the gateway moves the file into the app's own storage root.
  test('on Android 9 and older, moves the temp into the album under the '
      "app's storage root, without the plugin", () async {
    platform.sdkInt = 28;
    final MediaStorePlusGateway gateway = await readyGateway();
    final File temp = await tempFile('2024-01-05.mp4');

    final bool published = await gateway.publish(
      tempFilePath: temp.path,
      album: 'OneSecondDiary/Profiles/Work',
    );

    expect(published, isTrue);
    expect(platform.calls, isEmpty);
    expect(temp.existsSync(), isFalse);
    expect(
      File(
        '${paths.profileVideos(const ProfileKey('Work'))}2024-01-05.mp4',
      ).readAsStringSync(),
      'new',
    );
  });

  group('one call at a time (the fork answers from one shared slot)', () {
    test('a call reaches the plugin only once the call before it has '
        'answered', () async {
      final MediaStorePlusGateway gateway = await readyGateway();
      final File first = await tempFile('2024-01-05.mp4');
      final File second = await tempFile('2024-01-06.mp4');
      platform.holdSave = Completer<void>();

      final Future<bool> firstPublish = gateway.publish(
        tempFilePath: first.path,
        album: 'OneSecondDiary',
      );
      final Future<bool> secondPublish = gateway.publish(
        tempFilePath: second.path,
        album: 'OneSecondDiary/Movies',
      );
      await pumpEventQueue();
      final List<String> whileFirstIsPending = <String>[...platform.calls];
      platform.holdSave!.complete();

      expect(await firstPublish, isTrue);
      expect(await secondPublish, isTrue);
      expect(whileFirstIsPending, <String>[
        'saveFile ${first.path} as 2024-01-05.mp4 in DCIM/OneSecondDiary '
            '(video)',
      ]);
      expect(platform.calls.last, startsWith('saveFile ${second.path} '));
    });

    // A consent prompt still open, or a native failure the plugin never
    // answers. Deleting a profile must not wait 2 minutes per file.
    test('a call waiting 2 minutes behind one that has not answered gives up '
        'with a logged false, without reaching the plugin; later calls give '
        'up at once, until the plugin answers again', () {
      fakeAsync((FakeAsync async) {
        final MediaStorePlusGateway gateway = MediaStorePlusGateway(
          byPath: byPath(),
          mediaStore: MediaStore.new,
          logger: memoryLogger(log),
        );
        async.flushMicrotasks();
        platform.holdSave = Completer<void>();
        bool? deleted;
        bool? deletedLater;

        unawaited(
          gateway.publish(
            tempFilePath: '${paths.scratchDir}/job/2024-01-06.mp4',
            album: 'OneSecondDiary',
          ),
        );
        unawaited(
          gateway
              .delete(
                absolutePath: '${paths.videos}2024-01-05.mp4',
                album: 'OneSecondDiary',
              )
              .then((bool result) => deleted = result),
        );
        async.elapse(
          MediaStorePlusGateway.turnTimeLimit - const Duration(milliseconds: 1),
        );
        final bool? beforeTheLimit = deleted;
        async.elapse(const Duration(milliseconds: 1));

        expect(MediaStorePlusGateway.turnTimeLimit, const Duration(minutes: 2));
        expect(beforeTheLimit, isNull);
        expect(deleted, isFalse);
        expect(platform.calls, <String>[
          'saveFile ${paths.scratchDir}/job/2024-01-06.mp4 as 2024-01-06.mp4 '
              'in DCIM/OneSecondDiary (video)',
        ]);
        expect(log.lines, <String>[
          '[ERROR] 2024-01-05 10:00:00.000: [MediaGallery] Gave up deleting '
              '2024-01-05.mp4 from OneSecondDiary: publishing 2024-01-06.mp4 '
              'into OneSecondDiary has not answered for 2 minutes (a consent '
              'prompt still open, or a native failure the plugin never '
              'answers)',
        ]);

        unawaited(
          gateway
              .delete(
                absolutePath: '${paths.videos}2024-01-07.mp4',
                album: 'OneSecondDiary',
              )
              .then((bool result) => deletedLater = result),
        );
        async.flushMicrotasks();
        expect(deletedLater, isFalse);
        expect(
          log.lines.last,
          '[ERROR] 2024-01-05 10:00:00.000: [MediaGallery] Gave up deleting '
          '2024-01-07.mp4 from OneSecondDiary: publishing 2024-01-06.mp4 '
          'into OneSecondDiary still has not answered',
        );

        // The user answered the consent prompt at last (declined: a refused
        // save answers without touching the disk).
        platform.saveResult = false;
        platform.holdSave!.complete();
        async.flushMicrotasks();
        unawaited(
          gateway.publish(
            tempFilePath: '${paths.scratchDir}/job/2024-01-08.mp4',
            album: 'OneSecondDiary',
          ),
        );
        async.flushMicrotasks();
        expect(
          platform.calls.last,
          startsWith('saveFile ${paths.scratchDir}/job/2024-01-08.mp4 '),
        );
      });
    });
  });

  group('delete', () {
    test('step 1: a plain unlink, without the media store; a file already '
        'gone is deleted', () async {
      final MediaStorePlusGateway gateway = await readyGateway();
      final File clip = await seedClip(
        paths,
        ProfileKey.defaultProfile,
        LocalDay(2024, 1, 5),
      );

      expect(
        await gateway.delete(absolutePath: clip.path, album: 'OneSecondDiary'),
        isTrue,
      );
      expect(clip.existsSync(), isFalse);
      expect(
        await gateway.delete(absolutePath: clip.path, album: 'OneSecondDiary'),
        isTrue,
      );
      expect(platform.calls, isEmpty);
      expect(log.lines, isEmpty);
    });

    group('when the app cannot unlink the file (e.g. a clip from before a '
        'reinstall)', () {
      late String clipPath;

      setUp(() async {
        // A folder where the clip is: unlink fails, not "not found".
        final Directory unlinkable = Directory(
          '${paths.videos}Profiles/Work/2024-01-05.mp4',
        );
        await unlinkable.create(recursive: true);
        clipPath = unlinkable.path;
      });

      const String byName =
          'deleteFile 2024-01-05.mp4 in DCIM/OneSecondDiary/Profiles/Work '
          '(video)';
      const String lookUp =
          'getFileUri 2024-01-05.mp4 in DCIM/OneSecondDiary/Profiles/Work '
          '(video)';

      test('step 2 deletes it through the media store by name, in the album '
          'given; step 3, when the index has no such name, when that lookup '
          'fails or step 2 throws (as v1.7), scans the path and deletes by '
          'URI', () async {
        final List<String> scanAndDelete = <String>[
          'getUriFromFilePath $clipPath',
          'deleteFileUsingUri content://media/external/video/media/42 '
              'forceUseMediaStore=true',
        ];
        // (case, how the fake plugin answers, the calls it sees)
        final List<
          (String, void Function(FakeMediaStorePlatform), List<String>)
        >
        rows = <(String, void Function(FakeMediaStorePlatform), List<String>)>[
          ('found by name', (FakeMediaStorePlatform p) {}, <String>[byName]),
          (
            'not in the index',
            (FakeMediaStorePlatform p) => p.deleteResult = false,
            <String>[byName, lookUp, ...scanAndDelete],
          ),
          (
            'the lookup fails',
            (FakeMediaStorePlatform p) => p
              ..deleteResult = false
              ..indexedError = PlatformException(code: 'getFileUri'),
            <String>[byName, lookUp, ...scanAndDelete],
          ),
          (
            'step 2 throws',
            (FakeMediaStorePlatform p) =>
                p.deleteError = PlatformException(code: 'deleteFile'),
            <String>[byName, ...scanAndDelete],
          ),
        ];

        for (final (
              String name,
              void Function(FakeMediaStorePlatform) answer,
              List<String> calls,
            )
            in rows) {
          platform = FakeMediaStorePlatform();
          MediaStorePlatform.instance = platform;
          MediaStore.appFolder = 'OneSecondDiary/Movies';
          answer(platform);
          final MediaStorePlusGateway gateway = await readyGateway();

          expect(
            await gateway.delete(
              absolutePath: clipPath,
              album: 'OneSecondDiary/Profiles/Work',
            ),
            isTrue,
            reason: name,
          );
          expect(platform.calls, calls, reason: name);
        }
      });

      test('a refusal is a logged false, never a throw: a delete by name the '
          'user declined (without a second prompt from step 3), nothing found '
          'by the scan, a plugin error in step 3, a refused delete by '
          'URI', () async {
        // (case, how the fake plugin answers, the log line it ends with, the
        // calls it sees)
        final List<
          (String, void Function(FakeMediaStorePlatform), Matcher, Matcher)
        >
        rows =
            <(String, void Function(FakeMediaStorePlatform), Matcher, Matcher)>[
              (
                'declined by name',
                (FakeMediaStorePlatform p) => p
                  ..deleteResult = false
                  ..indexedUri = Uri.parse(
                    'content://media/external/video/media/7',
                  ),
                equals(
                  '[WARNING] 2024-01-05 10:00:00.000: [MediaGallery] Kept '
                  '2024-01-05.mp4 in OneSecondDiary/Profiles/Work: the user '
                  'declined to delete it',
                ),
                equals(<String>[byName, lookUp]),
              ),
              (
                'nothing found by the scan',
                (FakeMediaStorePlatform p) => p
                  ..deleteResult = false
                  ..scannedUri = null,
                startsWith(
                  '[ERROR] 2024-01-05 10:00:00.000: [MediaGallery] Could not '
                  'delete 2024-01-05.mp4 from OneSecondDiary/Profiles/Work',
                ),
                isNotEmpty,
              ),
              (
                'a plugin error in step 3',
                (FakeMediaStorePlatform p) => p
                  ..deleteResult = false
                  ..deleteUsingUriError = PlatformException(
                    code: 'deleteUsingUri',
                  ),
                startsWith(
                  '[ERROR] 2024-01-05 10:00:00.000: [MediaGallery] Could not '
                  'delete 2024-01-05.mp4 from OneSecondDiary/Profiles/Work',
                ),
                isNotEmpty,
              ),
              (
                'a refused delete by URI (consent declined)',
                (FakeMediaStorePlatform p) => p
                  ..deleteResult = false
                  ..deleteUsingUriResult = false,
                equals(
                  '[WARNING] 2024-01-05 10:00:00.000: [MediaGallery] MediaStore '
                  'refused to delete 2024-01-05.mp4 from '
                  'OneSecondDiary/Profiles/Work',
                ),
                isNotEmpty,
              ),
            ];

        for (final (
              String name,
              void Function(FakeMediaStorePlatform) answer,
              Matcher logged,
              Matcher calls,
            )
            in rows) {
          platform = FakeMediaStorePlatform();
          MediaStorePlatform.instance = platform;
          answer(platform);
          final MediaStorePlusGateway gateway = await readyGateway();

          expect(
            await gateway.delete(
              absolutePath: clipPath,
              album: 'OneSecondDiary/Profiles/Work',
            ),
            isFalse,
            reason: name,
          );
          expect(log.lines.last, logged, reason: name);
          expect(platform.calls, calls, reason: name);
        }
      });
    });
  });
}
