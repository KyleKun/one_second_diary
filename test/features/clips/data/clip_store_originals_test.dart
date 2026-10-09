// Keeping a recording's original: a save asked to
// keep its source moves the camera temp beside the diary and writes the
// recipe into the sidecar; "Edit again" renders from that source and
// leaves it where it is, never deleting a source the editor does not own;
// a save not asked to keep releases the temp as before, with no recipe.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/clip_recipe.dart';
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
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_queue.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/clip_write.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';

const ProfileKey _work = ProfileKey('Work');
final LocalDay _day = LocalDay(2024, 1, 5);
const StampStyle _coral = StampStyle(
  format: StampFormat.written,
  rgb: 0xEF5558,
  outline: false,
);

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late FakeMediaEngine engine;
  late ClipRepository repository;
  late ClipMetadataCache metadata;
  late OriginalsStore originals;
  late ClipStore store;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    final FakeMediaStoreGateway gallery = FakeMediaStoreGateway.onDisk(paths);
    engine = FakeMediaEngine(scratchDir: paths.scratchDir);
    repository = ClipRepository(
      scanner: ClipScanner(paths: paths, logger: memoryLogger(sink)),
      paths: paths,
      logger: memoryLogger(sink),
    );
    addTearDown(repository.dispose);
    metadata = ClipMetadataCache(paths: paths, logger: memoryLogger(sink));
    originals = OriginalsStore(
      paths: paths,
      gateway: gallery,
      logger: memoryLogger(sink),
      isAndroid: true,
    );
    addTearDown(originals.dispose);
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
    await repository.loadAll(active: _work, profiles: const <ProfileKey>[]);
  });

  /// A camera recording in the app's temp folder.
  Future<VideoSource> recording({List<int> bytes = const <int>[9, 9]}) async {
    final File file = File('${paths.temporaryDir}/REC_0001.mov');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return VideoSource(path: file.path, ownership: ClipOwnership.cameraTemp);
  }

  /// What the media engine renders for [source] (a real temp file).
  Future<(RenderedClip, VideoRender)> render(
    ClipSource source, {
    String outputFileName = '2024-01-05.mp4',
    int trimEndMs = 2500,
    StampStyle stamp = _coral,
    bool mute = false,
    SourceFrame? frame,
  }) async {
    final VideoRender request = VideoRender(
      sourcePath: source.path,
      fromRecording: source is VideoSource && source.fromRecording,
      trimStartMs: 500,
      trimEndMs: trimEndMs,
      outputFileName: outputFileName,
      stampText: '05/01/2024',
      stampStyle: stamp,
      legacyStampFont: false,
      location: const ClipLocation.off(),
      subtitles: '',
      format: const ClipFormat.legacy(VideoOrientation.landscape),
      albumLabel: 'Work',
      frame: frame,
      mute: mute,
    );
    return (await engine.renderClip(request), request);
  }

  ClipMeta? metaOf(ClipRef clip) => metadata.lookup(
    relPath: clip.relPath,
    stamp: repository.snapshotOf(_work)!.stampOf(clip)!,
  );

  test('a save asked to keep its source moves the camera temp beside the '
      'diary under the clip\'s name (its own extension), writes the recipe, '
      'and editAgainOf answers the source and the recipe; one not asked '
      'releases the temp and writes no recipe', () async {
    final VideoSource source = await recording();
    final (RenderedClip rendered, VideoRender request) = await render(
      source,
      mute: true,
      frame: const SourceFrame(
        frame: ClipFrame(scale: 1.5),
        sourceWidth: 1920,
        sourceHeight: 1080,
      ),
    );

    final ClipWrite saved = await store.save(
      rendered: rendered,
      request: request,
      source: source,
      profile: _work,
      day: _day,
      mode: const AddClip(),
      keepSource: true,
    );

    expect(saved.clip.relPath, 'Profiles/Work/2024-01-05.mp4');
    final File kept = File(
      originals.absoluteOf('Profiles/Work/2024-01-05.mov'),
    );
    expect(kept.readAsBytesSync(), <int>[9, 9]);
    expect(File(source.path).existsSync(), isFalse, reason: 'moved');
    expect(saved.undo.keptSourceRelPath, 'Profiles/Work/2024-01-05.mov');
    const ClipRecipe recipe = ClipRecipe(
      trimStartMs: 500,
      trimEndMs: 2500,
      frame: ClipFrame(scale: 1.5),
      sourceWidth: 1920,
      sourceHeight: 1080,
      stampStyle: _coral,
      mute: true,
      format: ClipFormat.legacy(VideoOrientation.landscape),
    );
    expect(metaOf(saved.clip)?.recipe, recipe);
    expect(store.editAgainOf(saved.clip), (
      sourcePath: kept.path,
      recipe: recipe,
      origin: ClipOrigin.osdRecording,
    ));

    // Not asked: the temp goes, no source, no recipe.
    final VideoSource plain = await recording();
    final (RenderedClip rendered2, VideoRender request2) = await render(
      plain,
      outputFileName: '2024-01-05-2.mp4',
    );
    final ClipWrite second = await store.save(
      rendered: rendered2,
      request: request2,
      source: plain,
      profile: _work,
      day: _day,
      mode: const AddClip(),
    );
    expect(File(plain.path).existsSync(), isFalse);
    expect(second.undo.keptSourceRelPath, isNull);
    expect(metaOf(second.clip)?.recipe, isNull);
    expect(store.editAgainOf(second.clip), isNull);
    expect(originals.sourceRelPaths, <String>{'Profiles/Work/2024-01-05.mp4'});
  });

  test('"Edit again": a replace rendered from the clip\'s own kept source '
      '(not the editor\'s to delete) leaves the source where it is, still '
      'the clip\'s by name, and the sidecar gets the new recipe; a gallery '
      'pick that replaces a clip with a source sends the source to the '
      'trash with the old clip', () async {
    final VideoSource source = await recording();
    final (RenderedClip rendered, VideoRender request) = await render(source);
    final ClipWrite saved = await store.save(
      rendered: rendered,
      request: request,
      source: source,
      profile: _work,
      day: _day,
      mode: const AddClip(),
      keepSource: true,
    );
    final String kept = store.editAgainOf(saved.clip)!.sourcePath;

    final VideoSource again = VideoSource(
      path: kept,
      ownership: ClipOwnership.cameraTemp,
      owned: false,
    );
    final (RenderedClip rendered2, VideoRender request2) = await render(
      again,
      trimEndMs: 5000,
    );
    final ClipWrite edited = await store.save(
      rendered: rendered2,
      request: request2,
      source: again,
      profile: _work,
      day: _day,
      mode: ReplaceClip(saved.clip),
      keepSource: true,
    );

    expect(edited.clip, saved.clip);
    expect(File(kept).readAsBytesSync(), <int>[9, 9], reason: 'untouched');
    expect(metaOf(edited.clip)?.recipe?.trimEndMs, 5000);
    expect(store.editAgainOf(edited.clip)?.sourcePath, kept);
    expect(
      sink.lines.where((String l) => l.contains('Could not delete')),
      isEmpty,
    );

    // A gallery pick in its place: the old source leaves with the old clip.
    final File picked = File('${paths.temporaryDir}/picked.mp4');
    await picked.writeAsBytes(<int>[4]);
    final VideoSource gallery = VideoSource(
      path: picked.path,
      ownership: ClipOwnership.userOriginal,
    );
    final (RenderedClip rendered3, VideoRender request3) = await render(
      gallery,
    );
    final ClipWrite replaced = await store.save(
      rendered: rendered3,
      request: request3,
      source: gallery,
      profile: _work,
      day: _day,
      mode: ReplaceClip(saved.clip),
      keepSource: true,
    );

    expect(File(kept).existsSync(), isFalse);
    expect(store.editAgainOf(replaced.clip), isNull);
    expect(metaOf(replaced.clip)?.recipe, isNull);
    expect(await store.undo(replaced), isTrue);
    expect(File(kept).readAsBytesSync(), <int>[9, 9]);
    expect(store.editAgainOf(saved.clip)?.sourcePath, kept);
  });
}
