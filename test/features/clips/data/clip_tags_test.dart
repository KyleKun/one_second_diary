import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/data/clip_tags.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_queue.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/clips/domain/thumbnail_tier.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/scripted_media_store_gateway.dart';

const ProfileKey _work = ProfileKey('Work');
const ProfileKey _default = ProfileKey.defaultProfile;
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
  late ClipTags tags;
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
    tags = ClipTags(
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

  List<String> libraryTags() => repository.snapshotOf(_work)!.tagsOf(clip);

  /// What the backfill would have cached for the clip as it is on disk.
  void cache({List<String>? tags}) => metadata.put(
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
      tags: tags,
    ),
  );

  test("sets the clip's tags: the library says so at once, the file is "
      "remuxed with them (one casing, sorted, no repeats) into the clip's "
      'place, the metadata cache knows the new version with its other facts '
      'kept, the thumbnails are kept and no backup is left; then none '
      'again', () async {
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

    final Future<void> tagging = tags.setTags(clip, <String>[
      'trip',
      'Bread',
      'TRIP',
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(libraryTags(), <String>[
      'Bread',
      'trip',
    ], reason: 'before the rewrite');
    await tagging;

    expect(engine.tagRequests.single.clipPath, file.path);
    expect(engine.tagRequests.single.tags, <String>['Bread', 'trip']);
    expect(file.readAsBytesSync(), fakeVideoBytes);
    expect(stampNow(), isNot(before));
    expect(libraryTags(), <String>['Bread', 'trip']);
    expect(tags.tagsOf(clip), <String>['Bread', 'trip']);
    final ClipMeta? meta = metadata.lookup(
      relPath: clip.relPath,
      stamp: stampNow(),
    );
    expect(meta?.tags, <String>['Bread', 'trip']);
    expect(meta?.subtitleText, 'Old text');
    expect(meta?.locationText, 'Tokyo, Japan');
    expect(metadata.tagsByRelPath, <String, List<String>>{
      clip.relPath: <String>['Bread', 'trip'],
    });
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

    // The same tags again, in another order: nothing to do.
    await tags.setTags(clip, <String>['Bread', 'trip']);
    expect(engine.tagRequests, hasLength(1));

    // None again: the tag is removed from the file.
    await tags.setTags(clip, const <String>[]);

    expect(engine.tagRequests.last.tags, isEmpty);
    expect(libraryTags(), isEmpty);
    expect(
      metadata.lookup(relPath: clip.relPath, stamp: stampNow())?.tags,
      isEmpty,
    );
    expect(metadata.tagsByRelPath, isEmpty);
  });

  test('a rewrite that fails is logged and thrown, and the library shows the '
      "clip's old tags again; a clip never read is left for the backfill to "
      'read', () async {
    repository.tagsKnown(clip.relPath, <String>['old']);
    engine.tagError = const VideoProcessingException(
      'ffmpeg failed',
      returnCode: 1,
      logTail: '',
    );

    await expectLater(
      tags.setTags(clip, <String>['new']),
      throwsA(isA<VideoProcessingException>()),
    );

    expect(libraryTags(), <String>['old']);
    expect(file.readAsBytesSync(), _original);
    expect(sink.lines.last, contains('[TAGS]'));

    // The gallery refuses the new file: the clip stays as it was.
    engine.tagError = null;
    gallery.publishResults.add(false);

    await expectLater(
      tags.setTags(clip, <String>['new']),
      throwsA(isA<MediaStoreException>()),
    );

    expect(libraryTags(), <String>['old']);
    expect(file.readAsBytesSync(), _original);

    // Not in the metadata cache: the rewrite caches nothing (the backfill
    // reads the new file, tags included), yet the library knows.
    await tags.setTags(clip, <String>['new']);

    expect(libraryTags(), <String>['new']);
    expect(metadata.lookup(relPath: clip.relPath, stamp: stampNow()), isNull);
  });

  test(
    'two edits of one clip run one after the other, the later one last',
    () async {
      cache();

      await Future.wait(<Future<void>>[
        tags.setTags(clip, <String>['first']),
        tags.setTags(clip, <String>['second']),
      ]);

      expect(
        engine.tagRequests
            .map((({String clipPath, List<String> tags}) r) => r.tags)
            .toList(),
        <List<String>>[
          <String>['first'],
          <String>['second'],
        ],
      );
      expect(libraryTags(), <String>['second']);
      expect(file.existsSync(), isTrue);
    },
  );

  test('the vocabulary is every tag of every profile with its clip count, '
      "most used first, named as the profile's own clips spell it", () async {
    await seedClip(paths, _work, LocalDay(2024, 1, 6));
    await seedClip(paths, _default, LocalDay(2024, 1, 7));
    await repository.loadAll(active: _work, profiles: <ProfileKey>[_default]);
    repository
      ..tagsKnown(clip.relPath, <String>['Trip', 'bread'])
      ..tagsKnown('Profiles/Work/2024-01-06.mp4', <String>['Trip'])
      ..tagsKnown('2024-01-07.mp4', <String>['TRIP', 'Kids']);

    expect(tags.vocabulary(profile: _work), const <TagCount>[
      TagCount(name: 'Trip', count: 3),
      TagCount(name: 'bread', count: 1),
      TagCount(name: 'Kids', count: 1),
    ]);
    expect(tags.vocabulary(profile: _default), const <TagCount>[
      TagCount(name: 'TRIP', count: 3),
      TagCount(name: 'bread', count: 1),
      TagCount(name: 'Kids', count: 1),
    ]);
    expect(tags.vocabulary().first, const TagCount(name: 'Trip', count: 3));
  });
}
