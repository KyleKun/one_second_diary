import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_privacy.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
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
  late ClipPrivacy privacy;
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
    addTearDown(metadata.dispose);
    thumbnailGateway = FakeThumbnailGateway();
    thumbnails = ThumbnailRepository(
      gateway: thumbnailGateway,
      queue: ThumbnailQueue(),
      metadata: metadata,
      paths: paths,
      logger: memoryLogger(sink),
    );
    privacy = ClipPrivacy(
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

  bool libraryPrivate() => repository.snapshotOf(_work)!.isPrivate(clip);

  /// What the backfill would have cached for the clip as it is on disk.
  void cache({bool? isPrivate}) => metadata.put(
    relPath: clip.relPath,
    stamp: stampNow(),
    meta: ClipMeta(
      durationMs: 1500,
      hasAudio: true,
      hasSubtitleStream: true,
      subtitleText: 'Old text',
      locationText: 'Tokyo, Japan',
      isOsdV15: true,
      width: 1920,
      height: 1080,
      codec: 'h264',
      isPrivate: isPrivate,
    ),
  );

  test('marks the clip private: the library says so at once, the file is '
      'remuxed with the mark into the clip\'s place, the metadata cache '
      'knows the new version as private with its other facts kept, the '
      'thumbnails are kept and no backup is left; then public again', () async {
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

    final Future<void> marking = privacy.setPrivate(clip, private: true);
    await Future<void>.delayed(Duration.zero);
    expect(libraryPrivate(), isTrue, reason: 'before the file is rewritten');
    await marking;

    expect(engine.privacyRequests.single, (clipPath: file.path, private: true));
    expect(file.readAsBytesSync(), fakeVideoBytes);
    expect(stampNow(), isNot(before));
    expect(libraryPrivate(), isTrue);
    final ClipMeta? meta = metadata.lookup(
      relPath: clip.relPath,
      stamp: stampNow(),
    );
    expect(meta?.isPrivate, isTrue);
    expect(meta?.subtitleText, 'Old text');
    expect(meta?.locationText, 'Tokyo, Japan');
    expect(metadata.privateRelPaths, <String>{clip.relPath});
    expect(
      thumbnails.cachedFile(
        clip,
        stamp: stampNow(),
        tier: ThumbnailTier.poster,
      ),
      isNotNull,
    );
    expect(thumbnailGateway.requests, hasLength(1));
    final Directory trash = Directory(paths.trashDir);
    expect(
      trash.existsSync() ? trash.listSync(recursive: true) : <Object>[],
      isEmpty,
    );

    // Already private: nothing to do.
    await privacy.setPrivate(clip, private: true);
    expect(engine.privacyRequests, hasLength(1));

    // Public again: the mark is removed from the file.
    await privacy.setPrivate(clip, private: false);

    expect(engine.privacyRequests.last.private, isFalse);
    expect(libraryPrivate(), isFalse);
    expect(
      metadata.lookup(relPath: clip.relPath, stamp: stampNow())?.isPrivate,
      isFalse,
    );
    expect(metadata.privateRelPaths, isEmpty);
  });

  test(
    'a rewrite that fails is logged and thrown, and the library shows the '
    'clip as it was; a clip never read is left for the backfill to read',
    () async {
      engine.privacyError = const VideoProcessingException(
        'ffmpeg failed',
        returnCode: 1,
        logTail: '',
      );

      await expectLater(
        privacy.setPrivate(clip, private: true),
        throwsA(isA<VideoProcessingException>()),
      );

      expect(libraryPrivate(), isFalse);
      expect(file.readAsBytesSync(), _original);
      expect(sink.lines.last, contains('[PRIVACY]'));

      // The gallery refuses the new file: the clip stays, public.
      engine.privacyError = null;
      gallery.publishResults.add(false);

      await expectLater(
        privacy.setPrivate(clip, private: true),
        throwsA(isA<MediaStoreException>()),
      );

      expect(libraryPrivate(), isFalse);
      expect(file.readAsBytesSync(), _original);

      // Not in the metadata cache: the rewrite caches nothing (the backfill
      // reads the new file, mark included), yet the library knows.
      await privacy.setPrivate(clip, private: true);

      expect(libraryPrivate(), isTrue);
      expect(metadata.lookup(relPath: clip.relPath, stamp: stampNow()), isNull);
    },
  );

  test(
    'two marks of one clip run one after the other, the later one last',
    () async {
      cache();

      await Future.wait(<Future<void>>[
        privacy.setPrivate(clip, private: true),
        privacy.setPrivate(clip, private: false),
      ]);

      expect(
        engine.privacyRequests.map(
          (({String clipPath, bool private}) r) => r.private,
        ),
        <bool>[true, false],
      );
      expect(libraryPrivate(), isFalse);
      expect(file.existsSync(), isTrue);
    },
  );
}
