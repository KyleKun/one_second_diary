// Converting from the source: a clip with a kept
// original and a recipe is rendered from the original with the normal save
// render at the new format (nothing lost), the new profile gets its own
// copy of the source only with "Keep original recordings" on and room for
// it, and the estimate and the report count the copies.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/clip_recipe.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/storage_budget.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/clips/data/profile_converter.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_queue.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_conversion.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../shared/fakes/fake_free_space_gateway.dart';
import '../../../support/support.dart';
import '../../movies/support/pausable_backfill.dart';

const ProfileKey _work = ProfileKey('Work');
const ProfileKey _work4k = ProfileKey('Work 4K');
const ClipFormat _legacy = ClipFormat.legacy(VideoOrientation.landscape);
const ClipFormat _ultra = ClipFormat(
  tier: ResolutionTier.p2160,
  orientation: VideoOrientation.landscape,
  codec: VideoCodec.hevc,
  fps: FrameRate.f60,
  channels: AudioChannels.stereo,
  range: DynamicRange.sdr,
);
const StampStyle _coral = StampStyle(
  format: StampFormat.written,
  rgb: 0xEF5558,
  outline: false,
);
const ClipRecipe _recipe = ClipRecipe(
  trimStartMs: 500,
  trimEndMs: 2000,
  frame: ClipFrame(scale: 1.5, dx: 0.1),
  sourceWidth: 1920,
  sourceHeight: 1080,
  stampStyle: _coral,
  mute: true,
  format: _legacy,
);
const List<int> _sourceBytes = <int>[5, 5, 5, 5, 5];

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late ClipRepository repository;
  late ClipMetadataCache metadata;
  late OriginalsStore originals;
  late ClipStore store;
  late FakeFreeSpaceGateway freeSpace;
  late FakeMediaEngine engine;
  late bool keep;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    final FakeMediaStoreGateway gallery = FakeMediaStoreGateway.onDisk(paths);
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
    freeSpace = FakeFreeSpaceGateway(free: 1 << 40);
    engine = FakeMediaEngine(scratchDir: paths.scratchDir);
    keep = true;
  });

  ProfileConverter converter() => ProfileConverter(
    engine: engine,
    store: store,
    clips: repository,
    metadata: metadata,
    freeSpace: freeSpace,
    wakelock: FakeWakelockGateway(),
    backfill: PausableBackfill(),
    formatOf: (ProfileKey key) => key == _work4k ? _ultra : _legacy,
    paths: paths,
    logger: memoryLogger(sink),
    originals: originals,
    stampTextOf: (LocalDay day, StampFormat format) =>
        '${format.name}:${day.fileStem}',
    keepOriginals: () => keep,
  );

  /// Two clips of Work: the 5th with a kept source and a recipe (read,
  /// tagged, with a place and a subtitle), the 6th with neither.
  Future<(ClipRef withSource, ClipRef plain)> seedWork() async {
    await seedClip(paths, _work, LocalDay(2024, 1, 5));
    await seedClip(paths, _work, LocalDay(2024, 1, 6));
    await Directory(paths.profileVideos(_work4k)).create(recursive: true);
    await repository.loadAll(active: _work, profiles: <ProfileKey>[_work4k]);
    final File source = File(
      originals.absoluteOf('Profiles/Work/2024-01-05.mov'),
    );
    await source.parent.create(recursive: true);
    await source.writeAsBytes(_sourceBytes);
    await originals.scanNames();
    final ClipIndex index = repository.snapshotOf(_work)!;
    final ClipRef five = index.clipsOn(LocalDay(2024, 1, 5)).single;
    final ClipRef six = index.clipsOn(LocalDay(2024, 1, 6)).single;
    metadata.put(
      relPath: five.relPath,
      stamp: index.stampOf(five)!,
      meta: const ClipMeta(
        durationMs: 1500,
        subtitleText: 'Hello',
        locationText: 'Lisbon',
        latitude: 38.7,
        longitude: -9.1,
        origin: ClipOrigin.osdRecording,
        isPrivate: true,
        tags: <String>['trip'],
        schema: ClipSchema.v15,
        recipe: _recipe,
      ),
    );
    metadata.put(
      relPath: six.relPath,
      stamp: index.stampOf(six)!,
      meta: const ClipMeta(durationMs: 2000, schema: ClipSchema.v15),
    );
    return (five, six);
  }

  test('a clip with a source and a recipe renders from the source with the '
      'normal save render at the new format (the recipe\'s window, frame '
      'with its size, stamp style and mute; the clip\'s subtitle, place, '
      'tags and privacy; the day\'s stamp text); the other converts from '
      'its file; the new profile gets a copy of the source with the recipe '
      'in its sidecar; the report and the estimate count it', () async {
    final (ClipRef five, ClipRef six) = await seedWork();

    final ConversionEstimate estimate = await converter().estimateConversion(
      source: _work,
      format: _ultra,
    );
    expect(estimate.sourceCopyBytes, _sourceBytes.length);
    expect(
      estimate.neededBytes,
      StorageBudget.convertBytes(format: _ultra, totalDurationMs: 3500) +
          _sourceBytes.length,
    );

    final List<ConversionEvent> events = await converter()
        .convertProfile(
          const ConversionJob(source: _work, target: _work4k, format: _ultra),
        )
        .toList();

    final VideoRender fromSource = engine.renderRequests.single as VideoRender;
    expect(fromSource.sourcePath, originals.sourcePathOf(five.relPath));
    expect(fromSource.fromRecording, isTrue);
    expect((fromSource.trimStartMs, fromSource.trimEndMs), (500, 2000));
    expect(fromSource.frame, _recipe.sourceFrame);
    expect(fromSource.stampStyle, _coral);
    expect(fromSource.stampText, 'written:2024-01-05');
    expect(fromSource.mute, isTrue);
    expect(fromSource.subtitles, 'Hello');
    expect(fromSource.location.text, 'Lisbon');
    expect(fromSource.location.latitude, 38.7);
    expect(fromSource.tags, <String>['trip']);
    expect(fromSource.isPrivate, isTrue);
    expect(fromSource.format, _ultra);
    expect(fromSource.albumLabel, 'Work 4K');
    expect(fromSource.outputFileName, '2024-01-05.mp4');
    expect(
      engine.convertRequests.single.sourcePath,
      paths.absoluteFromVideos(six.relPath),
    );

    final ConversionReport report = (events.last as ConversionFinished).report;
    expect(
      (report.done, report.sourcesCopied, report.sourcesSkipped),
      (2, 1, 0),
    );
    final File copy = File(
      originals.absoluteOf('Profiles/Work 4K/2024-01-05.mov'),
    );
    expect(copy.readAsBytesSync(), _sourceBytes);
    expect(
      File(
        originals.absoluteOf('Profiles/Work/2024-01-05.mov'),
      ).readAsBytesSync(),
      _sourceBytes,
      reason: 'the original is never touched',
    );
    final ClipIndex target = repository.snapshotOf(_work4k)!;
    final ClipRef converted = target.clipsOn(LocalDay(2024, 1, 5)).single;
    final ClipMeta? meta = metadata.lookup(
      relPath: converted.relPath,
      stamp: target.stampOf(converted)!,
    );
    expect(meta?.recipe, ClipRecipe.of(fromSource));
    expect(meta?.recipe?.format, _ultra);
    expect(meta?.subtitleText, 'Hello');
    expect(meta?.isPrivate, isTrue);
    expect(store.editAgainOf(converted)?.sourcePath, copy.path);
  });

  test('with "Keep original recordings" off, or no room for the copy, the '
      'new profile\'s clip is still rendered from the source but gets no '
      'source of its own (no recipe either), and the report says so; a '
      'source without a recipe converts from the stamped clip', () async {
    final (ClipRef five, ClipRef six) = await seedWork();
    keep = false;

    final List<ConversionEvent> off = await converter()
        .convertProfile(
          const ConversionJob(source: _work, target: _work4k, format: _ultra),
        )
        .toList();

    expect(engine.renderRequests, hasLength(1));
    final ConversionReport report = (off.last as ConversionFinished).report;
    expect((report.sourcesCopied, report.sourcesSkipped), (0, 1));
    expect(
      File(
        originals.absoluteOf('Profiles/Work 4K/2024-01-05.mov'),
      ).existsSync(),
      isFalse,
    );
    final ClipIndex target = repository.snapshotOf(_work4k)!;
    final ClipRef converted = target.clipsOn(LocalDay(2024, 1, 5)).single;
    expect(
      metadata
          .lookup(relPath: converted.relPath, stamp: target.stampOf(converted)!)
          ?.recipe,
      isNull,
    );
    expect(
      (await converter().estimateConversion(
        source: _work,
        format: _ultra,
      )).sourceCopyBytes,
      0,
    );

    // On, but no room: the same, logged.
    keep = true;
    freeSpace.free = StorageBudget.floorBytes;
    for (final ClipRef clip in target.newestFirst) {
      await store.delete(clip);
    }
    final List<ConversionEvent> full = await converter()
        .convertProfile(
          const ConversionJob(source: _work, target: _work4k, format: _ultra),
        )
        .toList();
    final ConversionReport fullReport =
        (full.last as ConversionFinished).report;
    expect((fullReport.sourcesCopied, fullReport.sourcesSkipped), (0, 1));
    expect(sink.lines.join('\n'), contains('No room to copy the original'));

    // A reinstall lost the recipe: the stamped clip is converted as any.
    metadata.put(
      relPath: five.relPath,
      stamp: repository.snapshotOf(_work)!.stampOf(five)!,
      meta: const ClipMeta(durationMs: 1500, schema: ClipSchema.v15),
    );
    engine.renderRequests.clear();
    engine.convertRequests.clear();
    for (final ClipRef clip in repository.snapshotOf(_work4k)!.newestFirst) {
      await store.delete(clip);
    }
    await converter()
        .convertProfile(
          const ConversionJob(source: _work, target: _work4k, format: _ultra),
        )
        .drain<void>();
    expect(engine.renderRequests, isEmpty);
    expect(
      engine.convertRequests.map((ConvertRequest r) => r.sourcePath),
      <String>[
        paths.absoluteFromVideos(five.relPath),
        paths.absoluteFromVideos(six.relPath),
      ],
    );
  });
}
