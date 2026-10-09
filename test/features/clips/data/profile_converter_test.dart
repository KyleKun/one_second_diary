// Converting a profile into a new one: every clip
// re-rendered in date order into the new profile under its own name, with a
// sidecar from the render and the old text facts; a manifest in the new
// folder lets a killed app resume; a cancel keeps what was converted; the
// estimate counts, measures, times (the phone check's speed) and budgets.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/osd_artist.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/storage_budget.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/data/conversion_manifest.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
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

/// What the engine's probe says of a clip the cache has not read.
ClipProbe _probe() => const ClipProbe(
  durationMs: 2000,
  hasAudio: true,
  hasSubtitleStream: false,
  artist: osdArtist,
  album: 'Work',
  comment: 'origin=osd_recording',
  locationTag: null,
  title: null,
  width: 1920,
  height: 1080,
  codec: 'h264',
  fps: 30,
  channels: 1,
);

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

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late ClipRepository repository;
  late ClipMetadataCache metadata;
  late ClipStore store;
  late FakeFreeSpaceGateway freeSpace;
  late FakeWakelockGateway wakelock;
  late PausableBackfill backfill;
  late FakeMediaEngine engine;

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
    store = ClipStore(
      publisher: MediaPublisher(
        gateway: gallery,
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
    freeSpace = FakeFreeSpaceGateway(free: 1 << 40);
    wakelock = FakeWakelockGateway();
    backfill = PausableBackfill();
    engine = FakeMediaEngine(scratchDir: paths.scratchDir);
  });

  ProfileConverter converter({double speed = 1}) => ProfileConverter(
    engine: engine,
    store: store,
    clips: repository,
    metadata: metadata,
    freeSpace: freeSpace,
    wakelock: wakelock,
    backfill: backfill,
    formatOf: (ProfileKey key) => key == _work4k ? _ultra : _legacy,
    paths: paths,
    logger: memoryLogger(sink),
    speedOf: (_) => speed,
  );

  /// Three clips of Work, the 5th read (2 s, tagged, with a place), the
  /// others not read yet.
  Future<List<ClipRef>> seedWork() async {
    for (final int day in <int>[7, 5, 6]) {
      await seedClip(paths, _work, LocalDay(2024, 1, day));
    }
    await Directory(paths.profileVideos(_work4k)).create(recursive: true);
    await repository.loadAll(active: _work, profiles: <ProfileKey>[_work4k]);
    final ClipIndex index = repository.snapshotOf(_work)!;
    final ClipRef five = index.clipsOn(LocalDay(2024, 1, 5)).single;
    metadata.put(
      relPath: five.relPath,
      stamp: index.stampOf(five)!,
      meta: const ClipMeta(
        durationMs: 2000,
        tags: <String>['trip'],
        locationText: 'Lisbon',
        origin: ClipOrigin.osdRecording,
        schema: ClipSchema.v15,
      ),
    );
    // The unread clips' lengths come from the engine's probe at render.
    for (final ClipRef clip in index.newestFirst) {
      if (clip == five) continue;
      engine.probes[paths.absoluteFromVideos(clip.relPath)] = _probe();
    }
    return index.newestFirst.toList().reversed.toList();
  }

  test('the estimate: the count, the total length (unread clips count as '
      'the average known), the time at the phone\'s speed, the space from '
      'the budget; the same format is not offered', () async {
    await seedWork();

    final ConversionEstimate estimate = await converter(
      speed: 2,
    ).estimateConversion(source: _work, format: _ultra);

    expect(estimate.clipCount, 3);
    expect(estimate.totalDurationMs, 6000);
    expect(estimate.estimatedTime, const Duration(seconds: 3));
    expect(
      estimate.neededBytes,
      StorageBudget.convertBytes(format: _ultra, totalDurationMs: 6000),
    );
    expect(estimate.verdict, const StorageOk());
    expect(estimate.sameFormat, isFalse);
    expect(estimate.canStart, isTrue);

    freeSpace.free = 0;
    final ConversionEstimate full = await converter().estimateConversion(
      source: _work,
      format: _ultra,
    );
    expect(full.verdict, isA<StorageShort>());
    expect(full.canStart, isFalse);

    final ConversionEstimate same = await converter().estimateConversion(
      source: _work,
      format: _legacy,
    );
    expect(same.sameFormat, isTrue);
    expect(same.canStart, isFalse);
  });

  test(
    'a run converts in date order into the new profile under the same '
    'names, writes each clip\'s sidecar from the render and the old text '
    'facts, keeps a manifest while it runs and removes it when done',
    () async {
      final List<ClipRef> clips = await seedWork();
      final ProfileConverter sut = converter();
      bool heldWhileWorking = false;

      final List<ConversionEvent> events = <ConversionEvent>[];
      await for (final ConversionEvent event in sut.convertProfile(
        const ConversionJob(source: _work, target: _work4k, format: _ultra),
      )) {
        events.add(event);
        if (event is ConversionProgress) {
          heldWhileWorking = wakelock.enabled && backfill.paused;
        }
      }

      expect(
        engine.convertRequests.map((ConvertRequest r) => r.outputFileName),
        <String>['2024-01-05.mp4', '2024-01-06.mp4', '2024-01-07.mp4'],
      );
      expect(engine.convertRequests.first.format, _ultra);
      expect(engine.convertRequests.first.albumLabel, 'Work 4K');
      expect(
        engine.convertRequests.first.sourcePath,
        paths.absoluteFromVideos(clips.first.relPath),
      );
      // The read clip's length and channels come from its cache entry,
      // the others' from the probe; the audio is left to the engine when
      // the layout is not known.
      expect(
        engine.convertRequests.map((ConvertRequest r) => r.durationMs),
        <int>[2000, 2000, 2000],
      );
      expect(engine.probedPaths, <String>[
        paths.absoluteFromVideos('Profiles/Work/2024-01-06.mp4'),
        paths.absoluteFromVideos('Profiles/Work/2024-01-07.mp4'),
      ]);
      expect(heldWhileWorking, isTrue);
      expect(wakelock.enabled, isFalse);

      final ConversionReport report =
          (events.last as ConversionFinished).report;
      expect(report.done, 3);
      expect(report.complete, isTrue);
      expect(
        events.whereType<ConversionClipDone>().map(
          (ConversionClipDone e) => e.target.relPath,
        ),
        <String>[
          'Profiles/Work 4K/2024-01-05.mp4',
          'Profiles/Work 4K/2024-01-06.mp4',
          'Profiles/Work 4K/2024-01-07.mp4',
        ],
      );
      final ConversionProgress first = events.first as ConversionProgress;
      expect((first.done, first.total), (0, 3));
      expect(first.remaining, const Duration(seconds: 6));

      final ClipIndex target = repository.snapshotOf(_work4k)!;
      expect(target.clipCount, 3);
      final ClipRef five = target.clipsOn(LocalDay(2024, 1, 5)).single;
      final ClipMeta meta = metadata.lookup(
        relPath: five.relPath,
        stamp: target.stampOf(five)!,
      )!;
      expect(meta.tags, <String>['trip']);
      expect(meta.locationText, 'Lisbon');
      expect(meta.origin, ClipOrigin.osdRecording);
      expect(meta.schema, ClipSchema.v2);
      expect(meta.codec, 'hevc');
      expect(
        (meta.width, meta.height, meta.fps, meta.channels),
        (3840, 2160, 60.0, 2),
      );
      expect(
        File(
          '${paths.profileVideos(_work4k)}${ConversionManifest.fileName}',
        ).existsSync(),
        isFalse,
      );
      expect(
        Directory(paths.profileVideos(_work)).listSync(),
        hasLength(3),
        reason: 'the originals are untouched',
      );
    },
  );

  test('a cancel ends after the clip in flight and keeps the manifest; the '
      'next run resumes after what is done; a clip that fails to render '
      'is skipped and the rest go on', () async {
    await seedWork();
    final CancelToken cancel = CancelToken();
    final ProfileConverter sut = converter();
    const ConversionJob job = ConversionJob(
      source: _work,
      target: _work4k,
      format: _ultra,
    );

    final List<ConversionEvent> firstRun = <ConversionEvent>[];
    await for (final ConversionEvent event in sut.convertProfile(
      job,
      cancelToken: cancel,
    )) {
      firstRun.add(event);
      if (event is ConversionClipDone) cancel.cancel();
    }
    final ConversionReport stopped =
        (firstRun.last as ConversionFinished).report;
    expect(stopped.cancelled, isTrue);
    expect(stopped.done, 1);
    final String manifestPath =
        '${paths.profileVideos(_work4k)}${ConversionManifest.fileName}';
    final ConversionManifest? manifest = await ConversionManifest.read(
      manifestPath,
    );
    expect(manifest?.done, <String>['Profiles/Work/2024-01-05.mp4']);
    expect(manifest?.format, _ultra.toString());

    // The second run skips the first clip; the 6th fails to render.
    engine.convertErrors.add(
      const VideoProcessingException('boom', returnCode: 1, logTail: ''),
    );
    engine.convertRequests.clear();
    final List<ConversionEvent> secondRun = await sut
        .convertProfile(job)
        .toList();

    expect(
      engine.convertRequests.map((ConvertRequest r) => r.outputFileName),
      <String>['2024-01-06.mp4', '2024-01-07.mp4'],
    );
    final ConversionReport report =
        (secondRun.last as ConversionFinished).report;
    expect(report.done, 2);
    expect(report.skipped.values, <ConversionSkipReason>[
      ConversionSkipReason.renderFailed,
    ]);
    expect(report.complete, isTrue);
    expect(File(manifestPath).existsSync(), isFalse);
    expect(repository.snapshotOf(_work4k)!.clipCount, 2);
  });
}
