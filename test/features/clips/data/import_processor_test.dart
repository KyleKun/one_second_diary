// Processing foreign videos, in the order that
// never loses a file: render into scratch with the normal save command,
// move the original beside the diary, publish under the day name. A refused
// move skips the file and keeps the original; a .mov beside the clips moves
// too; a declined batch consent skips everything; a cancel keeps what was
// done.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/data/import_processor.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_queue.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/imported_video.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../../support/support.dart';
import '../../../support/track_1c/read_only_folder.dart';
import '../../movies/support/pausable_backfill.dart';

const ProfileKey _work = ProfileKey('Work');
const ClipFormat _legacy = ClipFormat.legacy(VideoOrientation.landscape);

ClipProbe _probe(int durationMs, {String? colorTransfer}) => ClipProbe(
  durationMs: durationMs,
  colorTransfer: colorTransfer,
  hasAudio: true,
  hasSubtitleStream: false,
  artist: null,
  album: null,
  comment: null,
  locationTag: null,
  title: null,
  width: 1280,
  height: 720,
  codec: 'hevc',
  fps: 30,
);

String _stamp(LocalDay day, StampFormat format) => 'stamp ${day.fileStem}';

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late FakeMediaStoreGateway gallery;
  late FakeMediaEngine engine;
  late FakeWakelockGateway wakelock;
  late PausableBackfill backfill;
  late ClipRepository repository;
  late ClipMetadataCache metadata;
  late ClipStore store;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    gallery = FakeMediaStoreGateway.onDisk(paths);
    engine = FakeMediaEngine(scratchDir: paths.scratchDir);
    wakelock = FakeWakelockGateway();
    backfill = PausableBackfill();
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
        originals: OriginalsStore(
          paths: paths,
          gateway: gallery,
          logger: memoryLogger(sink),
          isAndroid: true,
        ),
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

  Future<ImportProcessor> processor({
    bool requiresWriteConsent = false,
  }) async => ImportProcessor(
    engine: engine,
    store: store,
    clips: repository,
    metadata: metadata,
    mediaStore: gallery,
    wakelock: wakelock,
    backfill: backfill,
    settings: SettingsRepository(prefs: await openLegacyPrefs(legacyPrefs())),
    formatOf: (_) => _legacy,
    paths: paths,
    logger: memoryLogger(sink),
    requiresWriteConsent: requiresWriteConsent,
    prefs: await openLegacyPrefs(legacyPrefs()),
    originals: OriginalsStore(
      paths: paths,
      gateway: gallery,
      logger: memoryLogger(sink),
      isAndroid: true,
    ),
  );

  /// A foreign clip of the 5th (indexed, cached as not the app's) and a
  /// .mov of the 6th beside it.
  Future<void> seedTwo() async {
    await seedClip(paths, _work, LocalDay(2024, 1, 5), bytes: <int>[5]);
    await seedFile(paths, 'Profiles/Work/2024-01-06.mov', bytes: <int>[6]);
    repository.foreignClipsKnown(<String>['Profiles/Work/2024-01-05.mp4']);
    await repository.loadAll(active: _work, profiles: const <ProfileKey>[]);
    final ClipIndex index = repository.snapshotOf(_work)!;
    final ClipRef five = index.clipsOn(LocalDay(2024, 1, 5)).single;
    metadata.put(
      relPath: five.relPath,
      stamp: index.stampOf(five)!,
      meta: const ClipMeta(durationMs: 4000, schema: ClipSchema.other),
    );
    engine.probes[paths.absoluteFromVideos('Profiles/Work/2024-01-06.mov')] =
        _probe(90000, colorTransfer: 'arib-std-b67');
  }

  test(
    'candidates: the indexed foreign clips with their cached length and '
    'the date-named files beside them; withDurations probes the rest',
    () async {
      await seedTwo();
      final ImportProcessor imports = await processor();

      final List<ImportedVideo> found = imports.candidates(<ProfileKey>[_work]);
      expect(found.map((ImportedVideo v) => v.relPath), <String>[
        'Profiles/Work/2024-01-05.mp4',
        'Profiles/Work/2024-01-06.mov',
      ]);
      expect(found.first.durationMs, 4000);
      expect(found.first.isIndexed, isTrue);
      expect(found.last.day, LocalDay(2024, 1, 6));
      expect(found.last.isIndexed, isFalse);

      final List<ImportedVideo> timed = await imports.withDurations(found);
      expect(timed.last.durationMs, 90000);
      expect(timed.last.colorTransfer, 'arib-std-b67', reason: 'the probe');
      expect(timed.first.colorTransfer, isNull, reason: 'the cache: SDR');
    },
  );

  test('each video: the normal save command (origin import, the first '
      'quick cut, the date stamp), the original moved beside the diary, '
      'the clip published under the day name as the app\'s own; a .mov '
      'moves too; the wakelock and the backfill bracket the run', () async {
    await seedTwo();
    final ImportProcessor imports = await processor();
    final List<ImportedVideo> videos = await imports.withDurations(
      imports.candidates(<ProfileKey>[_work]),
    );
    bool heldWhileWorking = false;
    engine.progress = const <double>[1.0];

    final List<ImportEvent> events = <ImportEvent>[];
    await for (final ImportEvent event in imports.process(
      videos,
      choices: const ImportChoices(
        keepWhole: false,
        dateStamp: true,
        quickCutMs: 1500,
      ),
      stampText: _stamp,
    )) {
      events.add(event);
      if (event is ImportProgress) heldWhileWorking = wakelock.enabled;
    }

    final ImportFinished finished = events.last as ImportFinished;
    expect(finished.report.processed.map((ClipRef c) => c.relPath), <String>[
      'Profiles/Work/2024-01-05.mp4',
      'Profiles/Work/2024-01-06.mp4',
    ]);
    expect(finished.report.skipped, isEmpty);
    expect(finished.report.cancelled, isFalse);
    expect(events.whereType<ImportVideoDone>(), hasLength(2));
    expect(heldWhileWorking, isTrue);
    expect(wakelock.enabled, isFalse);
    expect(backfill.paused, isFalse);

    // The render requests: the save command, trimmed to the quick cut,
    // stamped with the day, origin import, the profile's format.
    final List<VideoRender> renders = engine.renderRequests
        .cast<VideoRender>()
        .toList();
    expect(renders.map((VideoRender r) => r.trimEndMs), <int>[1500, 1500]);
    expect(renders.map((VideoRender r) => r.stampText), <String>[
      'stamp 2024-01-05',
      'stamp 2024-01-06',
    ]);
    expect(
      renders.every((VideoRender r) => r.origin == ClipOrigin.import),
      isTrue,
    );
    expect(renders.every((VideoRender r) => !r.fromRecording), isTrue);
    expect(renders.first.format, _legacy);
    expect(renders.first.albumLabel, 'Work');
    // An HDR import carries its transfer, so the save tone-maps it.
    expect(renders.map((VideoRender r) => r.sourceColorTransfer), <String?>[
      null,
      'arib-std-b67',
    ]);

    // The originals, mirrored beside the diary; the clips, the app's own.
    expect(
      File('${paths.originals}Profiles/Work/2024-01-05.mp4').readAsBytesSync(),
      <int>[5],
    );
    expect(
      File('${paths.originals}Profiles/Work/2024-01-06.mov').readAsBytesSync(),
      <int>[6],
    );
    expect(
      File(
        paths.absoluteFromVideos('Profiles/Work/2024-01-06.mov'),
      ).existsSync(),
      isFalse,
    );
    final ClipIndex index = repository.snapshotOf(_work)!;
    expect(index.clipCount, 2);
    expect(index.foreignCount, 0);
    for (final ClipRef clip in index.newestFirst) {
      expect(
        metadata
            .lookup(relPath: clip.relPath, stamp: index.stampOf(clip)!)
            ?.origin,
        ClipOrigin.import,
      );
    }
  });

  test(
    'keep the whole video caps at 60 s, and no date stamp burns no text',
    () async {
      await seedTwo();
      final ImportProcessor imports = await processor();
      final List<ImportedVideo> videos = await imports.withDurations(
        imports.candidates(<ProfileKey>[_work]),
      );

      await imports
          .process(
            videos,
            choices: const ImportChoices(
              keepWhole: true,
              dateStamp: false,
              quickCutMs: 1500,
            ),
            stampText: _stamp,
          )
          .drain<void>();

      final List<VideoRender> renders = engine.renderRequests
          .cast<VideoRender>()
          .toList();
      expect(renders.map((VideoRender r) => r.trimEndMs), <int>[4000, 60000]);
      expect(renders.every((VideoRender r) => r.stampText.isEmpty), isTrue);
    },
  );

  test('a declined batch consent (Android 11+) skips every video before any '
      'render; a refused move of one file skips that file, deletes its '
      'render and keeps the original', () async {
    await seedTwo();
    final ImportProcessor consented = await processor(
      requiresWriteConsent: true,
    );
    final List<ImportedVideo> videos = await consented.withDurations(
      consented.candidates(<ProfileKey>[_work]),
    );
    gallery.writeRequestResults.add(false);

    final List<ImportEvent> declined = await consented
        .process(
          videos,
          choices: const ImportChoices(
            keepWhole: false,
            dateStamp: true,
            quickCutMs: 1500,
          ),
          stampText: _stamp,
        )
        .toList();

    final ImportReport report = (declined.last as ImportFinished).report;
    expect(report.moveRefused, isTrue);
    expect(report.skipped.values, everyElement(ImportSkipReason.moveRefused));
    expect(engine.renderRequests, isEmpty);
    expect(
      gallery.calls.whereType<WriteRequestCall>().single.absolutePaths,
      <String>[
        paths.absoluteFromVideos('Profiles/Work/2024-01-05.mp4'),
        paths.absoluteFromVideos('Profiles/Work/2024-01-06.mov'),
      ],
    );

    // One file whose move is refused: the folder refuses the rename and
    // the gallery the delete.
    if (!makeReadOnly(paths.profileVideos(_work))) {
      markTestSkipped('root can write anywhere');
      return;
    }
    gallery.deleteResults.add(false);
    final ImportProcessor imports = await processor();
    final List<ImportEvent> events = await imports
        .process(
          <ImportedVideo>[videos.first],
          choices: const ImportChoices(
            keepWhole: false,
            dateStamp: true,
            quickCutMs: 1500,
          ),
          stampText: _stamp,
        )
        .toList();
    final ImportReport one = (events.last as ImportFinished).report;
    expect(one.skipped, <ImportedVideo, ImportSkipReason>{
      videos.first: ImportSkipReason.moveRefused,
    });
    expect(one.processed, isEmpty);
    expect(
      File(
        paths.absoluteFromVideos('Profiles/Work/2024-01-05.mp4'),
      ).readAsBytesSync(),
      <int>[5],
      reason: 'the original stays',
    );
    expect(
      Directory(paths.scratchDir).existsSync() &&
          Directory(paths.scratchDir)
              .listSync(recursive: true)
              .whereType<File>()
              .any((File f) => f.path.endsWith('2024-01-05.mp4')),
      isFalse,
      reason: 'the render is deleted',
    );
  });

  test(
    'a cancel ends after the video in flight and keeps what was done',
    () async {
      await seedTwo();
      final ImportProcessor imports = await processor();
      final List<ImportedVideo> videos = await imports.withDurations(
        imports.candidates(<ProfileKey>[_work]),
      );
      final CancelToken cancel = CancelToken();

      final List<ImportEvent> events = <ImportEvent>[];
      await for (final ImportEvent event in imports.process(
        videos,
        choices: const ImportChoices(
          keepWhole: false,
          dateStamp: true,
          quickCutMs: 1500,
        ),
        stampText: _stamp,
        cancelToken: cancel,
      )) {
        events.add(event);
        if (event is ImportVideoDone) cancel.cancel();
      }

      final ImportReport report = (events.last as ImportFinished).report;
      expect(report.cancelled, isTrue);
      expect(report.processed, hasLength(1));
      expect(
        File(
          paths.absoluteFromVideos('Profiles/Work/2024-01-06.mov'),
        ).existsSync(),
        isTrue,
      );
    },
  );
}
