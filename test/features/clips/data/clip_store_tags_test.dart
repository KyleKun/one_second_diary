import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
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
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/clip_write.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/scripted_media_store_gateway.dart';

const ProfileKey _work = ProfileKey('Work');
final LocalDay _day = LocalDay(2024, 1, 5);

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late FakeMediaEngine engine;
  late ClipRepository repository;
  late ClipMetadataCache metadata;
  late ClipStore store;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    engine = FakeMediaEngine(scratchDir: paths.scratchDir);
    repository = ClipRepository(
      scanner: ClipScanner(paths: paths, logger: memoryLogger(sink)),
      paths: paths,
      logger: memoryLogger(sink),
    );
    addTearDown(repository.dispose);
    metadata = ClipMetadataCache(paths: paths, logger: memoryLogger(sink));
    addTearDown(metadata.dispose);
    store = ClipStore(
      publisher: MediaPublisher(
        gateway: ScriptedMediaStoreGateway.onDisk(paths),
        paths: paths,
        logger: memoryLogger(sink),
        clock: FakeClock(DateTime(2024, 1, 5, 10)),
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
    await repository.loadAll(active: _work, profiles: <ProfileKey>[]);
  });

  /// Saves a camera recording as the clip of the day that [mode] says.
  Future<ClipWrite> save(
    ClipSaveMode mode, {
    List<String> tags = const <String>[],
  }) async {
    final File file = File('${paths.temporaryDir}/REC_0001.mp4');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(fakeVideoBytes);
    final VideoSource source = VideoSource(
      path: file.path,
      ownership: ClipOwnership.cameraTemp,
    );
    final VideoRender request = VideoRender(
      sourcePath: source.path,
      fromRecording: true,
      trimStartMs: 0,
      trimEndMs: 2500,
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
      tags: tags,
    );
    final RenderedClip rendered = await engine.renderClip(request);
    return store.save(
      rendered: rendered,
      request: request,
      source: source,
      profile: _work,
      day: _day,
      mode: mode,
    );
  }

  List<String> tagsOf(ClipRef clip) =>
      repository.snapshotOf(_work)!.tagsOf(clip);

  test(
    'a deleted tagged clip comes back with its tags when the delete is '
    "undone, and a new clip that takes a deleted clip's name has none",
    () async {
      final ClipRef clip = (await save(const AddClip())).clip;
      repository.tagsKnown(clip.relPath, <String>['bread', 'Trip']);
      expect(store.tagsOf(clip), <String>['bread', 'Trip']);

      final ClipWrite deleted = await store.delete(clip);
      expect(repository.snapshotOf(_work)!.clipsOn(_day), isEmpty);

      expect(await store.undo(deleted), isTrue);
      expect(tagsOf(clip), <String>['bread', 'Trip']);

      // Deleted for good, then recorded again under the same name: no tags.
      await store.dismiss(await store.delete(clip));
      final ClipRef again = (await save(const AddClip())).clip;
      expect(again, clip);
      expect(tagsOf(again), isEmpty);
    },
  );

  test("a clip saved in a tagged clip's place keeps the library's tags, and "
      'still has them when the replace is undone; one saved with its own '
      'tags has those written through', () async {
    final ClipRef clip = (await save(const AddClip())).clip;
    repository.tagsKnown(clip.relPath, <String>['trip']);

    final ClipWrite replaced = await save(ReplaceClip(clip));

    expect(replaced.clip, clip);
    expect(tagsOf(clip), <String>['trip']);

    expect(await store.undo(replaced), isTrue);
    expect(tagsOf(clip), <String>['trip']);

    // The saver renders a replacement with the tags: the facts follow.
    await save(ReplaceClip(clip), tags: <String>['kids', 'trip']);
    expect(
      metadata
          .lookup(
            relPath: clip.relPath,
            stamp: repository.snapshotOf(_work)!.stampOf(clip)!,
          )
          ?.tags,
      <String>['kids', 'trip'],
    );
    expect(metadata.tagsByRelPath, <String, List<String>>{
      clip.relPath: <String>['kids', 'trip'],
    });
  });
}
