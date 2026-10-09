// ClipSaver: the editor's Save over the media engine and the clip store.
// It renders into scratch, then files the clip; a cancel stops the render
// and leaves no file behind; a failure changes nothing in the diary (a
// replaced clip stays as it was); the screen stays on while it runs.
// Discarding the editor deletes the source only when it is the app's own
// temp.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_notes_tag.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/storage_budget.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clip_editor/data/clip_saver.dart';
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
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../../shared/fakes/fake_app_info_gateway.dart';
import '../../../shared/fakes/fake_free_space_gateway.dart';
import '../../../support/support.dart';
import '../../../support/track_1b/scripted_media_store_gateway.dart';
import '../../movies/support/pausable_backfill.dart';

final LocalDay _day = LocalDay(2024, 1, 5);

void main() {
  late AppPaths paths;
  late MemoryLogSink log;
  late ScriptedMediaStoreGateway gallery;
  late FakeMediaEngine engine;
  late FakeWakelockGateway wakelock;
  late FakeFreeSpaceGateway freeSpace;
  late PausableBackfill backfill;
  late ClipRepository repository;
  late ClipMetadataCache metadata;
  late ClipStore store;
  late ClipSaver saver;

  /// A saver over the same store, reading [settings] at each save.
  ClipSaver newSaver(SettingsRepository settings) => ClipSaver(
    engine: engine,
    store: store,
    wakelock: wakelock,
    backfill: backfill,
    freeSpace: freeSpace,
    paths: paths,
    logger: memoryLogger(log),
    isIOS: false,
    settings: settings,
    deviceInfo: FakeDeviceInfoGateway(),
    appInfo: FakeAppInfoGateway(),
    clock: FakeClock(DateTime(2024, 1, 5, 10)),
  );

  setUp(() async {
    paths = await createTestPaths();
    log = MemoryLogSink();
    gallery = ScriptedMediaStoreGateway.onDisk(paths);
    engine = FakeMediaEngine(scratchDir: paths.scratchDir);
    wakelock = FakeWakelockGateway();
    freeSpace = FakeFreeSpaceGateway(free: 1 << 40);
    backfill = PausableBackfill();
    repository = ClipRepository(
      scanner: ClipScanner(paths: paths, logger: memoryLogger(log)),
      paths: paths,
      logger: memoryLogger(log),
    );
    addTearDown(repository.dispose);
    metadata = ClipMetadataCache(paths: paths, logger: memoryLogger(log));
    store = ClipStore(
      publisher: MediaPublisher(
        gateway: gallery,
        paths: paths,
        logger: memoryLogger(log),
        clock: FakeClock(DateTime(2024, 1, 5, 10)),
      ),
      repository: repository,
      metadata: metadata,
      thumbnails: ThumbnailRepository(
        gateway: FakeThumbnailGateway(),
        queue: ThumbnailQueue(),
        metadata: metadata,
        paths: paths,
        logger: memoryLogger(log),
      ),
      paths: paths,
      logger: memoryLogger(log),
      isIOS: false,
    );
    saver = newSaver(
      SettingsRepository(prefs: await openLegacyPrefs(legacyPrefs())),
    );
    await repository.loadAll(
      active: ProfileKey.defaultProfile,
      profiles: <ProfileKey>[ProfileKey.defaultProfile],
    );
  });

  /// A camera recording in the app's temp folder.
  Future<VideoSource> recording() async {
    final File file = File('${paths.temporaryDir}/REC_0001.mp4');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(fakeVideoBytes);
    return VideoSource(path: file.path, ownership: ClipOwnership.cameraTemp);
  }

  VideoRender renderOf(
    ClipSource source, {
    List<String> tags = const <String>[],
  }) => VideoRender(
    sourcePath: source.path,
    fromRecording: true,
    trimStartMs: 0,
    trimEndMs: 1500,
    outputFileName: '2024-01-05.mp4',
    stampText: '01/05/2024',
    stampStyle: const StampStyle(
      format: StampFormat.numeric,
      rgb: 0xFFFFFF,
      outline: true,
    ),
    legacyStampFont: false,
    location: const ClipLocation.off(),
    subtitles: '',
    format: const ClipFormat.legacy(VideoOrientation.landscape),
    albumLabel: 'Default',
    tags: tags,
  );

  test('renders the clip, then files it in the diary', () async {
    final VideoSource source = await recording();

    final SavedClip saved = await saver.save(
      request: renderOf(source),
      source: source,
      profile: ProfileKey.defaultProfile,
      day: _day,
      mode: const AddClip(),
      cancelToken: CancelToken(),
      onProgress: (_) {},
      onPublishing: () {},
    );

    expect(
      saved.ref,
      ClipRef(profile: ProfileKey.defaultProfile, relPath: '2024-01-05.mp4'),
    );
    expect(File('${paths.videos}2024-01-05.mp4').existsSync(), isTrue);
    expect(File(source.path).existsSync(), isFalse);
  });

  Future<SavedClip> save(
    ClipSource source, {
    CancelToken? cancelToken,
    ClipSaveMode mode = const AddClip(),
    void Function(double fraction)? onProgress,
    void Function()? onPublishing,
    List<String> tags = const <String>[],
    ClipSaver? by,
  }) => (by ?? saver).save(
    request: renderOf(source, tags: tags),
    source: source,
    profile: ProfileKey.defaultProfile,
    day: _day,
    mode: mode,
    cancelToken: cancelToken ?? CancelToken(),
    onProgress: onProgress ?? (_) {},
    onPublishing: onPublishing ?? () {},
  );

  // The save's budget (twice the
  // clip's estimated size, above the 200 MB floor every job leaves free)
  // is checked against the free space before anything is rendered.
  test('refuses a save the phone has no room for before rendering, saying '
      'how much to free; an unknown free space never refuses', () async {
    final int needed = StorageBudget.saveBytes(
      format: const ClipFormat.legacy(VideoOrientation.landscape),
      durationMs: 1500,
    );
    freeSpace.free = StorageBudget.floorBytes + needed - 1000;
    final VideoSource source = await recording();

    await expectLater(
      save(source),
      throwsA(
        isA<StorageShortException>().having(
          (StorageShortException e) => e.shortfallBytes,
          'shortfallBytes',
          1000,
        ),
      ),
    );
    expect(engine.renderRequests, isEmpty);
    expect(wakelock.enabled, isFalse);
    expect(File(source.path).existsSync(), isTrue, reason: 'nothing touched');
    expect(log.lines, anyElement(contains('1000 bytes short')));

    freeSpace.free = null;
    await save(source);
    expect(engine.renderRequests, hasLength(1));
  });

  test('reports the render as it goes, then that the clip is being '
      'filed', () async {
    final List<String> events = <String>[];

    await save(
      await recording(),
      onProgress: (double fraction) => events.add('$fraction'),
      onPublishing: () => events.add('publishing'),
    );

    expect(events, <String>['0.5', '1.0', 'publishing']);
  });

  // The metadata backfill's probes never compete with the render (libx264
  // -preset slow).
  test('keeps the screen on and holds the metadata backfill while it '
      'renders and files the clip, and lets both go after, a failure '
      'too', () async {
    final List<(bool, bool)> held = <(bool, bool)>[];

    await save(
      await recording(),
      onProgress: (_) => held.add((wakelock.enabled, backfill.paused)),
      onPublishing: () => held.add((wakelock.enabled, backfill.paused)),
    );
    expect(held, <(bool, bool)>[(true, true), (true, true), (true, true)]);
    expect(wakelock.enabled, isFalse);
    expect(backfill.paused, isFalse);

    engine.renderErrors.add(
      const VideoProcessingException('failed', returnCode: 1, logTail: ''),
    );
    await expectLater(
      save(await recording()),
      throwsA(isA<VideoProcessingException>()),
    );
    expect(wakelock.enabled, isFalse);
    expect(backfill.paused, isFalse);
  });

  /// Every file under the engine's scratch folder.
  List<String> scratchFiles() => Directory(paths.scratchDir).existsSync()
      ? <String>[
          for (final FileSystemEntity entity in Directory(
            paths.scratchDir,
          ).listSync(recursive: true))
            if (entity is File) entity.path,
        ]
      : const <String>[];

  group('cancelled', () {
    test('while rendering: nothing is filed and no file is left; the source '
        'stays for another try', () async {
      final VideoSource source = await recording();
      final CancelToken token = CancelToken();
      bool published = false;

      await expectLater(
        save(
          source,
          cancelToken: token,
          // The render ends as the cancel comes in: its file is dropped.
          onProgress: (double fraction) {
            if (fraction == 1) token.cancel();
          },
          onPublishing: () => published = true,
        ),
        throwsA(isA<CancelledException>()),
      );

      expect(published, isFalse);
      expect(Directory(paths.videos).listSync().whereType<File>(), isEmpty);
      expect(scratchFiles(), isEmpty);
      expect(File(source.path).existsSync(), isTrue);
      expect(wakelock.enabled, isFalse);
    });
  });

  group('failed', () {
    test('a render that fails files nothing, keeps the source, and says '
        'why in the log', () async {
      final VideoSource source = await recording();
      engine.renderErrors.add(
        const VideoProcessingException(
          'Saving 2024-01-05.mp4 failed',
          returnCode: 1,
          logTail: 'Error while processing',
        ),
      );

      await expectLater(save(source), throwsA(isA<VideoProcessingException>()));

      expect(Directory(paths.videos).listSync().whereType<File>(), isEmpty);
      expect(File(source.path).existsSync(), isTrue);
      expect(wakelock.enabled, isFalse);
      expect(
        log.lines.where((String line) => line.contains('[SAVE]')),
        contains(contains('Could not save the clip of 2024-01-05')),
      );
    });

    test('a replace the gallery refuses leaves the old clip as it was '
        '(D B2)', () async {
      final File old = await seedClip(
        paths,
        ProfileKey.defaultProfile,
        _day,
        bytes: <int>[7, 7, 7],
      );
      final VideoSource source = await recording();
      gallery.publishResults.add(false);

      await expectLater(
        save(
          source,
          mode: ReplaceClip(
            ClipRef(
              profile: ProfileKey.defaultProfile,
              relPath: '2024-01-05.mp4',
            ),
          ),
        ),
        throwsA(isA<MediaStoreException>()),
      );

      expect(old.readAsBytesSync(), <int>[7, 7, 7]);
      expect(File(source.path).existsSync(), isTrue);
    });
  });

  test("discarding deletes a camera recording in the app's temp folder; it "
      "keeps the user's own gallery video, and a file outside the app's "
      'temp folders whatever it is called', () async {
    final VideoSource source = await recording();
    await saver.discardSource(source);
    expect(File(source.path).existsSync(), isFalse);

    final File own = File('${paths.temporaryDir}/pick/VID_1.mp4');
    await own.parent.create(recursive: true);
    await own.writeAsBytes(fakeVideoBytes);
    await saver.discardSource(
      VideoSource(path: own.path, ownership: ClipOwnership.userOriginal),
    );
    expect(own.existsSync(), isTrue);

    final File outside = await seedClip(paths, ProfileKey.defaultProfile, _day);
    await saver.discardSource(
      VideoSource(path: outside.path, ownership: ClipOwnership.pickerCopy),
    );
    expect(outside.existsSync(), isTrue);

    final File elsewhere = File(
      '${(await createTempRoot()).path}/REC_0002.mp4',
    );
    await elsewhere.writeAsBytes(fakeVideoBytes);
    await saver.discardSource(
      VideoSource(path: elsewhere.path, ownership: ClipOwnership.cameraTemp),
    );
    expect(elsewhere.existsSync(), isTrue);
  });

  group('what the clip is saved with', () {
    test('notes the phone, the app version and the moment in every clip '
        '("Device info in videos", on by default); not when the preference '
        'is off', () async {
      await save(await recording());

      final Map<String, String> note = ClipNotesTag.parse(
        engine.renderRequests.single.deviceTag,
      );
      expect(note['device'], 'Android 14 (SDK 34), Google Pixel 8');
      expect(note['app'], '2.0.0');
      expect(note['recorded'], startsWith('2024-01-05T10:00:00'));

      final ClipSaver without = newSaver(
        SettingsRepository(
          prefs: await openLegacyPrefs(
            legacyPrefs(
              extra: <String, Object>{PrefKeys.clipDeviceInfo.name: false},
            ),
          ),
        ),
      );
      await save(await recording(), by: without);
      expect(engine.renderRequests.last.deviceTag, isNull);
    });

    test(
      "a clip saved in a tagged clip's place carries exactly the tags "
      'the editor sends: its own, or none when the user cleared them',
      () async {
        final ClipRef clip = (await save(await recording())).ref;
        repository.tagsKnown(clip.relPath, <String>['bread', 'Trip']);
        expect(engine.renderRequests.single.tags, isEmpty);

        await save(
          await recording(),
          mode: ReplaceClip(clip),
          tags: <String>['kids'],
        );
        expect(engine.renderRequests.last.tags, <String>['kids']);
        expect(
          metadata
              .lookup(
                relPath: clip.relPath,
                stamp: repository
                    .snapshotOf(ProfileKey.defaultProfile)!
                    .stampOf(clip)!,
              )
              ?.tags,
          <String>['kids'],
        );

        await save(await recording(), mode: ReplaceClip(clip));
        expect(engine.renderRequests.last.tags, isEmpty);
      },
    );
  });
}
