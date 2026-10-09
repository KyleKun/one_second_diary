import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/data/clip_subtitles.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_queue.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/thumbnail_tier.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/scripted_media_store_gateway.dart';

const ProfileKey _work = ProfileKey('Work');
final LocalDay _day = LocalDay(2024, 1, 5);

/// The bytes of the clip as the user saved it (the remux writes others).
const List<int> _original = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9];

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late ScriptedMediaStoreGateway gallery;
  late FakeMediaEngine engine;
  late ClipRepository repository;
  late ClipMetadataCache metadata;
  late FakeThumbnailGateway thumbnailGateway;
  late ThumbnailRepository thumbnails;
  late ClipSubtitles subtitles;
  late ClipRef clip;
  late File file;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    gallery = ScriptedMediaStoreGateway.onDisk(paths);
    engine = FakeMediaEngine(scratchDir: paths.scratchDir);
    repository = ClipRepository(
      scanner: ClipScanner(paths: paths, logger: memoryLogger(sink)),
      paths: paths,
      logger: memoryLogger(sink),
    );
    addTearDown(repository.dispose);
    metadata = ClipMetadataCache(paths: paths, logger: memoryLogger(sink));
    thumbnailGateway = FakeThumbnailGateway();
    thumbnails = ThumbnailRepository(
      gateway: thumbnailGateway,
      queue: ThumbnailQueue(),
      metadata: metadata,
      paths: paths,
      logger: memoryLogger(sink),
    );
    subtitles = ClipSubtitles(
      engine: engine,
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
    );
    file = await seedClip(paths, _work, _day, bytes: _original);
    clip = ClipRef(profile: _work, relPath: paths.relativeToVideos(file.path));
    await repository.loadAll(active: _work, profiles: <ProfileKey>[]);
  });

  FileStamp stampNow() => repository.snapshotOf(_work)!.stampOf(clip)!;

  /// What the backfill would have cached for the clip as it is on disk.
  void cache({String subtitleText = 'Old text', int? durationMs = 1500}) =>
      metadata.put(
        relPath: clip.relPath,
        stamp: stampNow(),
        meta: ClipMeta(
          durationMs: durationMs,
          hasAudio: true,
          hasSubtitleStream: subtitleText.isNotEmpty,
          subtitleText: subtitleText,
          locationText: 'Tokyo, Japan',
          isOsdV15: true,
          width: 1920,
          height: 1080,
          codec: 'h264',
        ),
      );

  group('textOf', () {
    test('answers from the metadata cache, running no ffmpeg job; reads the '
        'clip when the cache does not describe it as it is on disk; a read '
        'that fails is logged and reported', () async {
      cache(subtitleText: 'Walk around Asakusa');
      engine.subtitles[file.path] = 'what the file says';

      expect(await subtitles.textOf(clip), 'Walk around Asakusa');

      // A cache entry for another version of the file: the clip is read.
      await file.writeAsBytes(<int>[9, 9]);
      await repository.clipReplaced(clip);
      expect(await subtitles.textOf(clip), 'what the file says');

      // A read that fails is logged and reported.
      {
        subtitles = ClipSubtitles(
          engine: _UnreadableEngine(scratchDir: paths.scratchDir),
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
        );

        await expectLater(
          subtitles.textOf(clip),
          throwsA(isA<VideoProcessingException>()),
        );
        expect(sink.lines.last, contains('[SUBTITLES]'));
      }
    });
  });

  group('rewrite', () {
    test('remuxes the clip with the trimmed text over its whole length, the '
        'gallery gets the new file in its place, the metadata cache knows the '
        'new version, and the thumbnails are kept with no backup left (no '
        'Undo)', () async {
      cache();

      await subtitles.rewrite(clip, '  A new line \n');

      expect(
        engine.remuxRequests.single,
        RemuxRequest(clipPath: file.path, text: 'A new line', durationMs: 1500),
      );
      expect(file.readAsBytesSync(), fakeVideoBytes);
      final ClipMeta? meta = metadata.lookup(
        relPath: clip.relPath,
        stamp: stampNow(),
      );
      expect(meta?.subtitleText, 'A new line');
      expect(meta?.hasSubtitleStream, isTrue);
      expect(meta?.locationText, 'Tokyo, Japan');
      expect(meta?.durationMs, 1500);
      expect(await subtitles.textOf(clip), 'A new line');

      // Keeps the thumbnails (the frames did not change) and no backup.
      {
        cache();
        final FileStamp before = stampNow();
        await thumbnails
            .request(
              clip,
              stamp: before,
              tier: ThumbnailTier.poster,
              orientation: VideoOrientation.landscape,
            )
            .file;

        await subtitles.rewrite(clip, 'A new line');

        expect(stampNow(), isNot(before));
        expect(
          thumbnails.cachedFile(
            clip,
            stamp: stampNow(),
            tier: ThumbnailTier.poster,
          ),
          isNotNull,
        );
        expect(thumbnailGateway.requests, hasLength(1));

        // The backup of the old clip is dropped once replaced: no Undo.
        final Directory trash = Directory(paths.trashDir);
        expect(
          trash.existsSync() ? trash.listSync(recursive: true) : <Object>[],
          isEmpty,
        );
      }
    });

    test('a clip whose length is not cached is probed once for it; empty text '
        'removes the subtitle stream (O6)', () async {
      engine.probes[file.path] = const ClipProbe(
        durationMs: 2200,
        hasAudio: true,
        hasSubtitleStream: false,
        artist: null,
        album: null,
        comment: null,
        locationTag: null,
        title: null,
        width: 1920,
        height: 1080,
        codec: 'h264',
        fps: 30,
      );

      await subtitles.rewrite(clip, 'Hi');

      expect(engine.remuxRequests.single.durationMs, 2200);

      // Empty text removes the subtitle stream.
      cache();

      await subtitles.rewrite(clip, '   ');

      expect(engine.remuxRequests.last.text, '');
      final ClipMeta? meta = metadata.lookup(
        relPath: clip.relPath,
        stamp: stampNow(),
      );
      expect(meta?.subtitleText, '');
      expect(meta?.hasSubtitleStream, isFalse);
    });

    test('a failed remux, or a gallery that refuses the new file, leaves the '
        'clip as it was (v1.7 deleted it first)', () async {
      cache();
      engine.remuxError = const VideoProcessingException(
        'remux failed',
        returnCode: 1,
        logTail: '',
      );

      await expectLater(
        subtitles.rewrite(clip, 'A new line'),
        throwsA(isA<VideoProcessingException>()),
      );

      expect(file.readAsBytesSync(), _original);
      expect(await subtitles.textOf(clip), 'Old text');
      expect(
        sink.lines.last,
        allOf(contains('[SUBTITLES]'), contains('2024-01-05.mp4')),
      );

      // A gallery that refuses the new file.
      {
        engine.remuxError = null;
        cache();
        gallery.publishResults.add(false);

        await expectLater(
          subtitles.rewrite(clip, 'A new line'),
          throwsA(isA<MediaStoreException>()),
        );

        expect(file.readAsBytesSync(), _original);
        expect(await subtitles.textOf(clip), 'Old text');
      }
    });
  });
}

/// A media engine whose ffmpeg never answers a subtitle read.
class _UnreadableEngine extends FakeMediaEngine {
  _UnreadableEngine({required super.scratchDir});

  @override
  Future<String> readSubtitles(String path) async =>
      throw const VideoProcessingException(
        'no answer',
        returnCode: null,
        logTail: '',
      );
}
