// Processing a foreign video: its original moves
// beside the diary FIRST, then the render is published under the day name
// and the clip becomes the app's own; a refused move changes nothing; a
// .mov original moves too; Undo brings the original back.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
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
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_queue.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/clip_write.dart';
import 'package:one_second_diary/features/clips/domain/undo_token.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../../../support/track_1c/read_only_folder.dart';

const ProfileKey _work = ProfileKey('Work');
final LocalDay _day = LocalDay(2024, 1, 5);

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late FakeMediaStoreGateway gallery;
  late FakeMediaEngine engine;
  late ClipRepository repository;
  late ClipMetadataCache metadata;
  late ClipStore store;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    gallery = FakeMediaStoreGateway.onDisk(paths);
    engine = FakeMediaEngine(scratchDir: paths.scratchDir);
    repository = ClipRepository(
      scanner: ClipScanner(paths: paths, logger: memoryLogger(sink)),
      paths: paths,
      logger: memoryLogger(sink),
    );
    addTearDown(repository.dispose);
    metadata = ClipMetadataCache(paths: paths, logger: memoryLogger(sink));
    final OriginalsStore originals = OriginalsStore(
      paths: paths,
      gateway: gallery,
      logger: memoryLogger(sink),
      isAndroid: true,
    );
    store = ClipStore(
      publisher: MediaPublisher(
        gateway: gallery,
        paths: paths,
        logger: memoryLogger(sink),
        clock: FakeClock(DateTime(2024, 1, 5, 10)),
        originals: originals,
      ),
      repository: repository,
      metadata: metadata,
      thumbnails: ThumbnailRepository(
        gateway: FakeThumbnailGateway(),
        queue: ThumbnailQueue(),
        metadata: metadata,
        paths: paths,
        logger: memoryLogger(sink),
      ),
      paths: paths,
      logger: memoryLogger(sink),
      isIOS: false,
    );
  });

  Future<(RenderedClip, VideoRender)> render(String sourcePath) async {
    final VideoRender request = VideoRender(
      sourcePath: sourcePath,
      fromRecording: false,
      trimStartMs: 0,
      trimEndMs: 1500,
      outputFileName: '2024-01-05.mp4',
      stampText: '05/01/2024',
      stampStyle: const StampStyle(
        format: StampFormat.numeric,
        rgb: 0xFFFFFF,
        outline: true,
      ),
      legacyStampFont: false,
      location: const ClipLocation.off(),
      subtitles: '',
      format: const ClipFormat.legacy(VideoOrientation.landscape),
      albumLabel: 'Work',
      imported: true,
    );
    return (await engine.renderClip(request), request);
  }

  test('an indexed foreign clip: the original moves beside the diary, the '
      'render takes its name, the facts say v2 schema and origin import, '
      'and the library no longer holds it as foreign; Undo brings the '
      'original back', () async {
    final File original = await seedClip(
      paths,
      _work,
      _day,
      bytes: <int>[1, 2, 3],
    );
    final ClipRef clip = ClipRef(
      profile: _work,
      relPath: 'Profiles/Work/2024-01-05.mp4',
    );
    repository.foreignClipsKnown(<String>[clip.relPath]);
    await repository.loadAll(active: _work, profiles: const <ProfileKey>[]);
    final (RenderedClip rendered, VideoRender request) = await render(
      original.path,
    );

    final ClipWrite? write = await store.saveProcessed(
      rendered: rendered,
      request: request,
      profile: _work,
      day: _day,
      sourceRelPath: clip.relPath,
      clip: clip,
    );

    expect(write?.clip, clip);
    expect(write?.undo, isA<OriginalMovedUndo>());
    final File kept = File('${paths.originals}Profiles/Work/2024-01-05.mp4');
    expect(kept.readAsBytesSync(), <int>[1, 2, 3], reason: 'the original');
    expect(original.readAsBytesSync(), fakeVideoBytes, reason: 'the render');
    final ClipIndex index = repository.snapshotOf(_work)!;
    expect(index.isForeign(clip), isFalse);
    expect(index.clipCount, 1);
    final ClipMeta meta = metadata.lookup(
      relPath: clip.relPath,
      stamp: index.stampOf(clip)!,
    )!;
    expect(meta.schema, ClipSchema.v15, reason: 'the legacy format');
    expect(meta.origin, ClipOrigin.import);
    expect(File(rendered.tempPath).existsSync(), isFalse);

    expect(await store.undo(write!), isTrue);
    expect(original.readAsBytesSync(), <int>[1, 2, 3]);
    expect(kept.existsSync(), isFalse);
    expect(repository.snapshotOf(_work)!.clipCount, 1);
  });

  test('a .mov beside the clips is moved all the same and the render takes '
      "the day's free name; the editor's replace of a foreign clip with its "
      'own file takes the same road', () async {
    final File mov = await seedFile(
      paths,
      'Profiles/Work/2024-01-05.mov',
      bytes: <int>[9],
    );
    await repository.loadAll(active: _work, profiles: const <ProfileKey>[]);
    final (RenderedClip rendered, VideoRender request) = await render(mov.path);

    final ClipWrite? write = await store.saveProcessed(
      rendered: rendered,
      request: request,
      profile: _work,
      day: _day,
      sourceRelPath: 'Profiles/Work/2024-01-05.mov',
    );

    expect(write?.clip.relPath, 'Profiles/Work/2024-01-05.mp4');
    expect(mov.existsSync(), isFalse);
    expect(
      File('${paths.originals}Profiles/Work/2024-01-05.mov').readAsBytesSync(),
      <int>[9],
    );

    // By hand: the clip editor replaces the foreign clip with a render of
    // the clip's own file.
    final ClipRef clip = write!.clip;
    final (RenderedClip again, VideoRender againRequest) = await render(
      paths.absoluteFromVideos(clip.relPath),
    );
    final ClipWrite replaced = await store.save(
      rendered: again,
      request: againRequest,
      source: VideoSource(
        path: paths.absoluteFromVideos(clip.relPath),
        ownership: ClipOwnership.userOriginal,
        owned: false,
      ),
      profile: _work,
      day: _day,
      mode: ReplaceClip(clip),
    );
    expect(replaced.undo, isA<OriginalMovedUndo>());
    expect(
      File('${paths.originals}Profiles/Work/2024-01-05.mp4').existsSync(),
      isTrue,
    );
    expect(Directory(paths.trashDir).existsSync(), isFalse, reason: 'no trash');
  });

  test('a .mov of a day that already has a clip: the render takes the next '
      'ordinal and the original is kept under THAT name, so it is the '
      'source of the processed clip, never of the day\'s first', () async {
    await seedClip(paths, _work, _day, bytes: <int>[1]);
    final File mov = await seedFile(
      paths,
      'Profiles/Work/2024-01-05.mov',
      bytes: <int>[9],
    );
    await repository.loadAll(active: _work, profiles: const <ProfileKey>[]);
    final (RenderedClip rendered, VideoRender request) = await render(mov.path);

    final ClipWrite? write = await store.saveProcessed(
      rendered: rendered,
      request: request,
      profile: _work,
      day: _day,
      sourceRelPath: 'Profiles/Work/2024-01-05.mov',
    );

    expect(write?.clip.relPath, 'Profiles/Work/2024-01-05-2.mp4');
    expect(
      File(
        '${paths.originals}Profiles/Work/2024-01-05-2.mov',
      ).readAsBytesSync(),
      <int>[9],
    );
    expect(
      File('${paths.originals}Profiles/Work/2024-01-05.mov').existsSync(),
      isFalse,
    );
    expect(
      store.editAgainOf(write!.clip)?.sourcePath,
      '${paths.originals}Profiles/Work/2024-01-05-2.mov',
    );
    final ClipRef first = ClipRef(
      profile: _work,
      relPath: 'Profiles/Work/2024-01-05.mp4',
    );
    expect(store.editAgainOf(first), isNull);
    expect(
      File(paths.absoluteFromVideos(first.relPath)).readAsBytesSync(),
      <int>[1],
      reason: 'the day\'s first clip is untouched',
    );

    // Undo: the clip goes, the .mov comes back where it was.
    expect(await store.undo(write), isTrue);
    expect(mov.readAsBytesSync(), <int>[9]);
    expect(
      File('${paths.originals}Profiles/Work/2024-01-05-2.mov').existsSync(),
      isFalse,
    );
  });

  test('a refused move leaves the original where it is, deletes the render '
      'and saves nothing', () async {
    final File original = await seedClip(paths, _work, _day);
    final ClipRef clip = ClipRef(
      profile: _work,
      relPath: 'Profiles/Work/2024-01-05.mp4',
    );
    await repository.loadAll(active: _work, profiles: const <ProfileKey>[]);
    if (!makeReadOnly(paths.profileVideos(_work))) {
      markTestSkipped('root can write anywhere');
      return;
    }
    gallery.deleteResults.add(false);
    final (RenderedClip rendered, VideoRender request) = await render(
      original.path,
    );

    final ClipWrite? write = await store.saveProcessed(
      rendered: rendered,
      request: request,
      profile: _work,
      day: _day,
      sourceRelPath: clip.relPath,
      clip: clip,
    );

    expect(write, isNull);
    expect(original.existsSync(), isTrue);
    expect(File(rendered.tempPath).existsSync(), isFalse);
    expect(
      Directory(paths.originals).listSync().whereType<File>().where(
        (File f) => !f.path.endsWith('.nomedia'),
      ),
      isEmpty,
    );
    expect(repository.snapshotOf(_work)!.clipCount, 1);
  });

  test('re-recording over a foreign clip (another source, not the clip\'s '
      'own file): the user\'s file moves beside the diary under the clip\'s '
      'name, never to the trash, with no recipe; the camera temp is '
      'released, not kept; Undo puts the file back. A clip the app made '
      'keeps the trash road', () async {
    final File imported = await seedClip(
      paths,
      _work,
      _day,
      bytes: <int>[1, 2, 3],
    );
    final ClipRef clip = ClipRef(
      profile: _work,
      relPath: 'Profiles/Work/2024-01-05.mp4',
    );
    repository.foreignClipsKnown(<String>[clip.relPath]);
    await repository.loadAll(active: _work, profiles: const <ProfileKey>[]);
    final File temp = File('${paths.temporaryDir}/REC_1.mp4');
    await temp.parent.create(recursive: true);
    await temp.writeAsBytes(<int>[5, 5]);
    final (RenderedClip rendered, VideoRender request) = await render(
      temp.path,
    );

    final ClipWrite write = await store.save(
      rendered: rendered,
      request: request,
      source: VideoSource(path: temp.path, ownership: ClipOwnership.cameraTemp),
      profile: _work,
      day: _day,
      mode: ReplaceClip(clip),
      keepSource: true,
    );

    expect(write.undo, isA<OriginalMovedUndo>());
    final File kept = File('${paths.originals}Profiles/Work/2024-01-05.mp4');
    expect(kept.readAsBytesSync(), <int>[1, 2, 3], reason: "the user's file");
    expect(imported.readAsBytesSync(), fakeVideoBytes, reason: 'the render');
    expect(Directory(paths.trashDir).existsSync(), isFalse, reason: 'no trash');
    expect(temp.existsSync(), isFalse, reason: 'the camera temp is released');
    expect(repository.snapshotOf(_work)!.isForeign(clip), isFalse);
    expect(store.editAgainOf(clip), (
      sourcePath: kept.path,
      recipe: null,
    ), reason: 'the kept file is not what the clip was rendered from');

    expect(await store.undo(write), isTrue);
    expect(imported.readAsBytesSync(), <int>[1, 2, 3]);
    expect(kept.existsSync(), isFalse);

    // The app's own clip, re-recorded: the old one goes to the trash.
    final LocalDay next = LocalDay(2024, 1, 6);
    final File own = await seedClip(paths, _work, next, bytes: <int>[4]);
    final ClipRef ownClip = ClipRef(
      profile: _work,
      relPath: 'Profiles/Work/2024-01-06.mp4',
    );
    await repository.loadAll(active: _work, profiles: const <ProfileKey>[]);
    final File temp2 = File('${paths.temporaryDir}/REC_2.mp4');
    await temp2.writeAsBytes(<int>[6]);
    final (RenderedClip again, VideoRender againRequest) = await render(
      temp2.path,
    );
    final ClipWrite replaced = await store.save(
      rendered: again,
      request: againRequest,
      source: VideoSource(
        path: temp2.path,
        ownership: ClipOwnership.cameraTemp,
      ),
      profile: _work,
      day: next,
      mode: ReplaceClip(ownClip),
    );
    expect(replaced.undo, isA<ReplacedUndo>());
    expect(own.readAsBytesSync(), fakeVideoBytes);
    expect(Directory(paths.trashDir).existsSync(), isTrue);
    expect(
      File('${paths.originals}Profiles/Work/2024-01-06.mp4').existsSync(),
      isFalse,
    );
  });
}
