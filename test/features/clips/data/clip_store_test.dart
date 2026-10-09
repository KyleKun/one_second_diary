import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/rendered_clip.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_queue.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/clip_write.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/undo_token.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/scripted_media_store_gateway.dart';

const ProfileKey _work = ProfileKey('Work');
final LocalDay _day = LocalDay(2024, 1, 5);

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late ScriptedMediaStoreGateway gallery;
  late FakeThumbnailGateway thumbnailGateway;
  late FakeMediaEngine engine;
  late ClipRepository repository;
  late ClipMetadataCache metadata;
  late ThumbnailRepository thumbnails;
  late ClipStore store;

  /// Builds the store and its collaborators over [at], laid out as on
  /// Android or, with [isIOS], as on iOS.
  Future<void> openStore(AppPaths at, {required bool isIOS}) async {
    paths = at;
    sink = MemoryLogSink();
    gallery = ScriptedMediaStoreGateway.onDisk(paths);
    thumbnailGateway = FakeThumbnailGateway();
    engine = FakeMediaEngine(scratchDir: paths.scratchDir);
    repository = ClipRepository(
      scanner: ClipScanner(paths: paths, logger: memoryLogger(sink)),
      paths: paths,
      logger: memoryLogger(sink),
    );
    addTearDown(repository.dispose);
    metadata = ClipMetadataCache(paths: paths, logger: memoryLogger(sink));
    thumbnails = ThumbnailRepository(
      gateway: thumbnailGateway,
      queue: ThumbnailQueue(),
      metadata: metadata,
      paths: paths,
      logger: memoryLogger(sink),
    );
    store = ClipStore(
      publisher: MediaPublisher(
        gateway: gallery,
        paths: paths,
        logger: memoryLogger(sink),
        clock: FakeClock(DateTime(2024, 1, 5, 10)),
      ),
      repository: repository,
      metadata: metadata,
      thumbnails: thumbnails,
      paths: paths,
      logger: memoryLogger(sink),
      isIOS: isIOS,
    );
    await repository.loadAll(
      active: _work,
      profiles: <ProfileKey>[ProfileKey.defaultProfile],
    );
  }

  setUp(() async => openStore(await createTestPaths(), isIOS: false));

  /// A camera recording in the app's temp folder.
  Future<VideoSource> recording() async {
    final File file = File('${paths.temporaryDir}/REC_0001.mp4');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(fakeVideoBytes);
    return VideoSource(path: file.path, ownership: ClipOwnership.cameraTemp);
  }

  /// What the media engine renders for [source] (a real temp file).
  Future<(RenderedClip, VideoRender)> render(
    ClipSource source, {
    String outputFileName = '2024-01-05.mp4',
    String subtitles = '',
    ClipLocation location = const ClipLocation.off(),
  }) async {
    final VideoRender request = VideoRender(
      sourcePath: source.path,
      fromRecording: source is VideoSource && source.fromRecording,
      trimStartMs: 0,
      trimEndMs: 2500,
      outputFileName: outputFileName,
      stampText: '05/01/2024',
      stampStyle: const StampStyle(
        format: StampFormat.numeric,
        rgb: 0xFFFFFF,
        outline: true,
      ),
      legacyStampFont: false,
      location: location,
      subtitles: subtitles,
      format: const ClipFormat.legacy(VideoOrientation.landscape),
      albumLabel: 'Work',
    );
    return (await engine.renderClip(request), request);
  }

  group('add', () {
    test("the day's first clip takes the bare name in the profile folder "
        'and joins the index, even when the folder was deleted (B 4.1); '
        'another clip of the day takes the next ordinal, the first untouched '
        "(D1); the clip's facts are written through to the metadata cache, so "
        'the backfill never probes it', () async {
      final VideoSource source = await recording();
      final (RenderedClip rendered, VideoRender request) = await render(source);

      final ClipWrite saved = await store.save(
        rendered: rendered,
        request: request,
        source: source,
        profile: _work,
        day: _day,
        mode: const AddClip(),
      );

      expect(saved.clip.relPath, 'Profiles/Work/2024-01-05.mp4');
      expect(
        File(paths.absoluteFromVideos(saved.clip.relPath)).existsSync(),
        isTrue,
      );
      expect(repository.snapshotOf(_work)!.clipsOn(_day), <ClipRef>[
        saved.clip,
      ]);

      // Another clip of the day takes the next ordinal; the first is not
      // renamed or touched.
      final File first = File(paths.absoluteFromVideos(saved.clip.relPath));
      final List<int> firstBytes = await first.readAsBytes();
      final VideoSource again = await recording();
      final (RenderedClip rendered2, VideoRender request2) = await render(
        again,
      );
      final ClipWrite second = await store.save(
        rendered: rendered2,
        request: request2,
        source: again,
        profile: _work,
        day: _day,
        mode: const AddClip(),
      );

      expect(second.clip.relPath, 'Profiles/Work/2024-01-05-2.mp4');
      expect(await first.readAsBytes(), firstBytes);
      expect(
        repository
            .snapshotOf(_work)!
            .clipsOn(_day)
            .map((ClipRef c) => c.relPath),
        <String>[
          'Profiles/Work/2024-01-05.mp4',
          'Profiles/Work/2024-01-05-2.mp4',
        ],
      );

      // Saves into a profile whose folder was deleted.
      {
        await openStore(await createTestPaths(), isIOS: false);
        gallery.strictFolders = true;
        final VideoSource source = await recording();
        final (RenderedClip rendered, VideoRender request) = await render(
          source,
        );

        final ClipWrite saved = await store.save(
          rendered: rendered,
          request: request,
          source: source,
          profile: _work,
          day: _day,
          mode: const AddClip(),
        );

        expect(
          File(paths.absoluteFromVideos(saved.clip.relPath)).existsSync(),
          isTrue,
        );
      }

      // The clip's facts, written through.
      {
        final VideoSource source = await recording();
        final (RenderedClip rendered, VideoRender request) = await render(
          source,
          subtitles: 'Hello',
          location: const ClipLocation(
            enabled: true,
            text: 'Tokyo, Japan',
            latitude: 35.71,
            longitude: 139.79,
          ),
        );

        final ClipWrite saved = await store.save(
          rendered: rendered,
          request: request,
          source: source,
          profile: _work,
          day: _day,
          mode: const AddClip(),
        );

        final FileStamp stamp = repository
            .snapshotOf(_work)!
            .stampOf(saved.clip)!;
        expect(
          metadata.lookup(relPath: saved.clip.relPath, stamp: stamp),
          const ClipMeta(
            durationMs: 2500,
            // The engine's answer, copied as is: the shared fake engine does
            // not report audio, so a movie probes this clip once.
            hasAudio: null,
            hasSubtitleStream: true,
            subtitleText: 'Hello',
            locationText: 'Tokyo, Japan',
            latitude: 35.71,
            longitude: 139.79,
            isOsdV15: true,
            width: 1920,
            height: 1080,
            codec: 'h264',
            origin: ClipOrigin.osdRecording,
          ),
        );
      }
    });

    test('a clip kept in a sub-folder also counts: the new clip never takes '
        'its name at the root (O1); gaps are not filled (rule a); a file the '
        'index has not seen yet is never overwritten', () async {
      await seedClip(paths, _work, _day, subFolder: 'trip');
      await repository.rescan(_work);
      final VideoSource source = await recording();
      final (RenderedClip rendered, VideoRender request) = await render(source);

      final ClipWrite saved = await store.save(
        rendered: rendered,
        request: request,
        source: source,
        profile: _work,
        day: _day,
        mode: const AddClip(),
      );

      expect(saved.clip.relPath, 'Profiles/Work/2024-01-05-2.mp4');
      expect(
        repository
            .snapshotOf(_work)!
            .clipsOn(_day)
            .map((ClipRef c) => c.relPath),
        <String>[
          'Profiles/Work/trip/2024-01-05.mp4',
          'Profiles/Work/2024-01-05-2.mp4',
        ],
      );

      // On a day whose ordinals have gaps the new clip follows the highest
      // one, even though a lower name is free on disk.
      final LocalDay gappy = LocalDay(2024, 1, 6);
      await seedClip(paths, _work, gappy);
      await seedClip(paths, _work, gappy, ordinal: 4);
      await repository.rescan(_work);
      final VideoSource next = await recording();
      final (RenderedClip rendered2, VideoRender request2) = await render(
        next,
        outputFileName: '2024-01-06.mp4',
      );
      final ClipWrite afterGap = await store.save(
        rendered: rendered2,
        request: request2,
        source: next,
        profile: _work,
        day: gappy,
        mode: const AddClip(),
      );
      expect(afterGap.clip.relPath, 'Profiles/Work/2024-01-06-5.mp4');

      // Never overwrites a file the index has not seen yet (copied in since
      // the last scan).
      {
        await openStore(await createTestPaths(), isIOS: false);
        final File copiedIn = await seedClip(
          paths,
          _work,
          _day,
          bytes: <int>[1],
        );
        final VideoSource source = await recording();
        final (RenderedClip rendered, VideoRender request) = await render(
          source,
        );

        final ClipWrite saved = await store.save(
          rendered: rendered,
          request: request,
          source: source,
          profile: _work,
          day: _day,
          mode: const AddClip(),
        );

        expect(saved.clip.relPath, 'Profiles/Work/2024-01-05-2.mp4');
        expect(await copiedIn.readAsBytes(), <int>[1]);
      }
    });

    test('a refused publish throws a MediaStoreException and changes '
        'nothing; the recording is kept for another try', () async {
      gallery.publishResults.add(false);
      final VideoSource source = await recording();
      final (RenderedClip rendered, VideoRender request) = await render(source);

      await expectLater(
        store.save(
          rendered: rendered,
          request: request,
          source: source,
          profile: _work,
          day: _day,
          mode: const AddClip(),
        ),
        throwsA(isA<MediaStoreException>()),
      );
      expect(repository.snapshotOf(_work)!.hasDay(_day), isFalse);
      expect(File(source.path).existsSync(), isTrue);
      expect(File(rendered.tempPath).existsSync(), isFalse);
    });
  });

  group('replace', () {
    test('publishes the new version under the same name and refreshes its '
        'index entry; a refused publish throws and the old clip survives '
        'untouched (I CL-03: v1.7 had deleted it already)', () async {
      final File old = await seedClip(paths, _work, _day, bytes: <int>[1]);
      final ClipRef clip = (await repository.rescan(
        _work,
      )).clipsOn(_day).single;
      final VideoSource source = await recording();
      final (RenderedClip rendered, VideoRender request) = await render(source);
      final int newSize = await File(rendered.tempPath).length();

      final ClipWrite saved = await store.save(
        rendered: rendered,
        request: request,
        source: source,
        profile: _work,
        day: _day,
        mode: ReplaceClip(clip),
      );

      expect(saved.clip, clip);
      expect(saved.undo, isA<ReplacedUndo>());
      expect(await old.length(), newSize);
      expect(repository.snapshotOf(_work)!.stampOf(clip)!.sizeBytes, newSize);

      // A refused publish.
      {
        final File old = await seedClip(paths, _work, _day, bytes: <int>[1]);
        final ClipRef clip = (await repository.rescan(
          _work,
        )).clipsOn(_day).single;
        gallery.publishResults.add(false);
        final VideoSource source = await recording();
        final (RenderedClip rendered, VideoRender request) = await render(
          source,
        );

        await expectLater(
          store.save(
            rendered: rendered,
            request: request,
            source: source,
            profile: _work,
            day: _day,
            mode: ReplaceClip(clip),
          ),
          throwsA(isA<MediaStoreException>()),
        );
        expect(await old.readAsBytes(), <int>[1]);
        expect(File(source.path).existsSync(), isTrue);
      }
    });

    test('a legacy profile literally named "Default" keeps its clips in its '
        'own folder (Z-03: v1.7 re-published them at the root)', () async {
      const ProfileKey namedDefault = ProfileKey('Default');
      final File old = await seedClip(
        paths,
        namedDefault,
        _day,
        bytes: <int>[1],
      );
      final ClipRef clip = (await repository.rescan(
        namedDefault,
      )).clipsOn(_day).single;
      final VideoSource source = await recording();
      final (RenderedClip rendered, VideoRender request) = await render(source);

      await store.save(
        rendered: rendered,
        request: request,
        source: source,
        profile: namedDefault,
        day: _day,
        mode: ReplaceClip(clip),
      );

      expect(
        gallery.calls.whereType<PublishCall>().map((PublishCall c) => c.album),
        <String>['OneSecondDiary/Profiles/Default'],
      );
      expect(old.path, endsWith('/Profiles/Default/2024-01-05.mp4'));
      expect(await old.readAsBytes(), isNot(<int>[1]));
      expect(
        File(paths.absoluteFromVideos('2024-01-05.mp4')).existsSync(),
        isFalse,
      );
    });
  });

  group('source file', () {
    Future<void> saveFrom(ClipSource source, {ClipSaveMode? mode}) async {
      final (RenderedClip rendered, VideoRender request) = await render(source);
      await store.save(
        rendered: rendered,
        request: request,
        source: source,
        profile: _work,
        day: _day,
        mode: mode ?? const AddClip(),
      );
    }

    test(
      'a gallery video outside the app container is never deleted, even '
      'when a caller mislabels it as a picker copy (invariant 12); on iOS the '
      "camera and picker temps are deleted, another app's file is kept",
      () async {
        final Directory elsewhere = await createTempRoot('osd_gallery_');
        final File gallery = File('${elsewhere.path}/DCIM/Camera/VID_2.mp4');
        await gallery.parent.create(recursive: true);
        await gallery.writeAsBytes(fakeVideoBytes);

        await saveFrom(
          VideoSource(path: gallery.path, ownership: ClipOwnership.pickerCopy),
        );

        expect(gallery.existsSync(), isTrue);
        expect(sink.lines.last, contains('outside the app container'));

        // On iOS the camera and picker temps in tmp/ and Library/Caches are
        // deleted, another app's file is kept.
        {
          final String root = (await createTempRoot()).path;
          final String container = '$root/Containers/Data/Application/0A1B';
          final AppPaths ios = AppPaths.fromPlatform(
            isIOS: true,
            documents: '$container/Documents',
            applicationSupport: '$container/Library/Application Support',
            externalStorage: null,
            temporary: '$container/Library/Caches',
            cache: '$container/Library/Caches',
          );
          await ios.createDirectories();
          await openStore(ios, isIOS: true);
          Future<File> fileAt(String path) async {
            final File file = File(path);
            await file.parent.create(recursive: true);
            return file.writeAsBytes(fakeVideoBytes);
          }

          final File camera = await fileAt('$container/tmp/camera/REC_1.mov');
          final File picked = await fileAt(
            '$container/Library/Caches/pick.mov',
          );
          final File foreign = await fileAt(
            '$root/Containers/Data/Application/9Z8Y/Documents/export.mov',
          );
          await saveFrom(
            VideoSource(path: camera.path, ownership: ClipOwnership.cameraTemp),
          );
          await saveFrom(
            VideoSource(path: picked.path, ownership: ClipOwnership.pickerCopy),
          );
          await saveFrom(
            VideoSource(
              path: foreign.path,
              ownership: ClipOwnership.pickerCopy,
            ),
          );

          expect(
            <String, bool>{
              'camera': camera.existsSync(),
              'picked': picked.existsSync(),
              'foreign': foreign.existsSync(),
            },
            <String, bool>{'camera': false, 'picked': false, 'foreign': true},
          );
        }
      },
    );

    test('re-importing a diary clip onto its own day adds a second clip and '
        'keeps the first, even if the source is flagged deletable (Z-05: v1.7 '
        'deleted the only copy); re-editing a clip from itself keeps the new '
        'version (the source is the destination)', () async {
      final File own = await seedClip(paths, _work, _day, bytes: <int>[1]);
      await repository.rescan(_work);

      await saveFrom(
        VideoSource(path: own.path, ownership: ClipOwnership.pickerCopy),
      );

      expect(await own.readAsBytes(), <int>[1]);
      expect(
        repository
            .snapshotOf(_work)!
            .clipsOn(_day)
            .map((ClipRef c) => c.relPath),
        <String>[
          'Profiles/Work/2024-01-05.mp4',
          'Profiles/Work/2024-01-05-2.mp4',
        ],
      );

      // Re-editing a clip from itself keeps the new version, even when the
      // source is flagged deletable.
      {
        await openStore(await createTestPaths(), isIOS: false);
        final File own = await seedClip(paths, _work, _day, bytes: <int>[1]);
        final ClipRef clip = (await repository.rescan(
          _work,
        )).clipsOn(_day).single;

        await saveFrom(
          VideoSource(path: own.path, ownership: ClipOwnership.platformExport),
          mode: ReplaceClip(clip),
        );

        expect(own.existsSync(), isTrue);
        expect(await own.readAsBytes(), isNot(<int>[1]));
      }
    });

    test('every ownership: only the user original survives the save, a camera '
        'recording is deleted (I CL-01, RG-02: derived from ownership, never '
        'from a preference)', () async {
      final Map<ClipOwnership, bool> kept = <ClipOwnership, bool>{};
      for (final ClipOwnership ownership in ClipOwnership.values) {
        final File file = File('${paths.temporaryDir}/${ownership.name}.mp4');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(fakeVideoBytes);
        await saveFrom(VideoSource(path: file.path, ownership: ownership));
        kept[ownership] = file.existsSync();
      }

      expect(kept, <ClipOwnership, bool>{
        ClipOwnership.cameraTemp: false,
        ClipOwnership.pickerCopy: false,
        ClipOwnership.userOriginal: true,
        ClipOwnership.platformExport: false,
      });
    });
  });

  group('delete', () {
    test(
      'deletes the clip through the gallery and takes it out of the '
      'index, and a hidden duplicate shows again; a refused delete throws '
      'and the clip stays, on disk and in the index (v1.7 counted it down)',
      () async {
        await seedClip(paths, _work, _day);
        await seedClip(paths, _work, _day, subFolder: 'old');
        final ClipRef visible = (await repository.rescan(
          _work,
        )).clipsOn(_day).single;

        final ClipWrite deleted = await store.delete(visible);

        expect(deleted.undo, isA<DeletedUndo>());
        expect(
          File(paths.absoluteFromVideos(visible.relPath)).existsSync(),
          isFalse,
        );
        expect(
          repository
              .snapshotOf(_work)!
              .clipsOn(_day)
              .map((ClipRef c) => c.relPath),
          <String>['Profiles/Work/old/2024-01-05.mp4'],
        );

        // A refused delete throws and the clip stays.
        {
          await openStore(await createTestPaths(), isIOS: false);
          await seedClip(paths, _work, _day);
          final ClipRef clip = (await repository.rescan(
            _work,
          )).clipsOn(_day).single;
          gallery.deleteResults.add(false);

          await expectLater(
            store.delete(clip),
            throwsA(isA<MediaStoreException>()),
          );

          expect(
            File(paths.absoluteFromVideos(clip.relPath)).existsSync(),
            isTrue,
          );
          expect(repository.snapshotOf(_work)!.clipsOn(_day), <ClipRef>[clip]);
        }
      },
    );
  });

  group('undo', () {
    Future<ClipWrite> saveNew({ClipSaveMode mode = const AddClip()}) async {
      final VideoSource source = await recording();
      final (RenderedClip rendered, VideoRender request) = await render(source);
      return store.save(
        rendered: rendered,
        request: request,
        source: source,
        profile: _work,
        day: _day,
        mode: mode,
      );
    }

    test('of a new clip deletes it and forgets it (index and metadata); of a '
        'delete puts the clip back in the index', () async {
      final ClipWrite saved = await saveNew();
      final FileStamp stamp = repository
          .snapshotOf(_work)!
          .stampOf(saved.clip)!;

      expect(await store.undo(saved), isTrue);

      expect(
        File(paths.absoluteFromVideos(saved.clip.relPath)).existsSync(),
        isFalse,
      );
      expect(repository.snapshotOf(_work)!.hasDay(_day), isFalse);
      expect(
        metadata.lookup(relPath: saved.clip.relPath, stamp: stamp),
        isNull,
      );

      // Undo of a delete.
      {
        await seedClip(paths, _work, _day);
        final ClipRef clip = (await repository.rescan(
          _work,
        )).clipsOn(_day).single;
        final ClipWrite deleted = await store.delete(clip);

        expect(await store.undo(deleted), isTrue);

        expect(repository.snapshotOf(_work)!.clipsOn(_day), <ClipRef>[clip]);
      }
    });

    test('of a replace puts the old clip back, on disk and in the index; '
        'once the snackbar is dismissed it is no longer possible: the backup '
        'is gone from the trash', () async {
      final File old = await seedClip(paths, _work, _day, bytes: <int>[1]);
      final ClipRef clip = (await repository.rescan(
        _work,
      )).clipsOn(_day).single;
      final ClipWrite replaced = await saveNew(mode: ReplaceClip(clip));

      expect(await store.undo(replaced), isTrue);

      expect(await old.readAsBytes(), <int>[1]);
      expect(repository.snapshotOf(_work)!.stampOf(clip)!.sizeBytes, 1);

      // Not possible once the snackbar is dismissed.
      {
        await openStore(await createTestPaths(), isIOS: false);
        await seedClip(paths, _work, _day, bytes: <int>[1]);
        final ClipRef clip = (await repository.rescan(
          _work,
        )).clipsOn(_day).single;
        final ClipWrite replaced = await saveNew(mode: ReplaceClip(clip));

        await store.dismiss(replaced);

        expect(await store.undo(replaced), isFalse);
        expect(Directory(paths.trashDir).listSync(), isEmpty);
      }
    });
  });
}
