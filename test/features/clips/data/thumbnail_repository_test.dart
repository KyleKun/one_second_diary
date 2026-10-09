import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_queue.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_ticket.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/clips/domain/thumbnail_tier.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/eventually.dart';

const ProfileKey _work = ProfileKey('Work');
const FileStamp _stamp = FileStamp(sizeBytes: 8, modifiedMs: 1704448800000);
const VideoOrientation _landscape = VideoOrientation.landscape;

ClipRef _clip(int day) => ClipRef(
  profile: _work,
  relPath: 'Profiles/Work/${LocalDay(2024, 1, day).fileStem}.mp4',
);

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late FakeThumbnailGateway gateway;
  late ClipMetadataCache metadata;
  late ThumbnailRepository thumbnails;

  setUp(() async {
    final ThumbnailQueue queue = ThumbnailQueue();
    paths = await createTestPaths();
    sink = MemoryLogSink();
    gateway = FakeThumbnailGateway();
    metadata = ClipMetadataCache(paths: paths, logger: memoryLogger(sink));
    thumbnails = ThumbnailRepository(
      gateway: gateway,
      queue: queue,
      metadata: metadata,
      paths: paths,
      logger: memoryLogger(sink),
    );
  });

  /// The bounds the gateway was asked for, by video file name.
  Map<String, (int, int)> boundsAsked() => <String, (int, int)>{
    for (final ThumbnailRequest request in gateway.requests)
      request.videoPath.split('/').last: (request.maxWidth, request.maxHeight),
  };

  test('writes a cell thumbnail into the thumbs folder, bounded both ways '
      'with the aspect ratio of the frame (never a square: Android 8.0 '
      'stretches to the bounds), named by the clip path, its stamp and the '
      'width', () async {
    final String? file = await thumbnails
        .request(
          _clip(5),
          stamp: _stamp,
          tier: ThumbnailTier.cell,
          orientation: _landscape,
        )
        .file;

    expect(
      file,
      matches(
        RegExp(
          '^${RegExp.escape(paths.thumbsDir)}/'
          r'[0-9a-f]{16}_1704448800000_8_200\.jpg$',
        ),
      ),
    );
    expect(File(file!).existsSync(), isTrue);
    expect(
      gateway.requests.single,
      ThumbnailRequest(
        videoPath: paths.absoluteFromVideos(_clip(5).relPath),
        outputPath: file,
        maxWidth: 200,
        maxHeight: 113,
        quality: 75,
        timeMs: 0,
      ),
    );

    // Bounds keep the aspect ratio of the frame, never a square: Android
    // 8.0 (API 26) stretches every frame to exactly the bounds given.
    // Known sizes win over the profile's canvas (a landscape clip in a
    // profile set to portrait, say).
    metadata.put(
      relPath: _clip(3).relPath,
      stamp: _stamp,
      meta: const ClipMeta(width: 1080, height: 1920),
    );
    metadata.put(
      relPath: _clip(4).relPath,
      stamp: _stamp,
      meta: const ClipMeta(width: 640),
    );
    final List<Future<String?>> files = <Future<String?>>[
      for (final (int day, VideoOrientation canvas, ThumbnailTier tier)
          in <(int, VideoOrientation, ThumbnailTier)>[
            (1, _landscape, ThumbnailTier.poster),
            (2, VideoOrientation.portrait, ThumbnailTier.cell),
            (3, _landscape, ThumbnailTier.cell),
            (4, VideoOrientation.portrait, ThumbnailTier.poster),
          ])
        thumbnails
            .request(_clip(day), stamp: _stamp, tier: tier, orientation: canvas)
            .file,
    ];
    await Future.wait(files);

    expect(boundsAsked(), <String, (int, int)>{
      '2024-01-05.mp4': (200, 113),
      '2024-01-01.mp4': (720, 405),
      '2024-01-02.mp4': (113, 200),
      '2024-01-03.mp4': (113, 200),
      '2024-01-04.mp4': (405, 720), // a width alone is no size
    });
  });

  test('serves a thumbnail an earlier session made without making it again, '
      'and knows it synchronously after load; a frame that cannot be '
      'extracted gives null and is logged', () async {
    final String made = (await thumbnails
        .request(
          _clip(5),
          stamp: _stamp,
          tier: ThumbnailTier.cell,
          orientation: _landscape,
        )
        .file)!;
    final FakeThumbnailGateway nextGateway = FakeThumbnailGateway();
    final ThumbnailRepository nextLaunch = ThumbnailRepository(
      gateway: nextGateway,
      queue: ThumbnailQueue(),
      metadata: metadata,
      paths: paths,
      logger: memoryLogger(sink),
    );

    final String? served = await nextLaunch
        .request(
          _clip(5),
          stamp: _stamp,
          tier: ThumbnailTier.cell,
          orientation: _landscape,
        )
        .file;

    expect(served, made);
    expect(nextGateway.requests, isEmpty);

    // After load, it is known synchronously, so the first poster of a
    // launch shows in the same frame.
    final ThumbnailRepository thirdLaunch = ThumbnailRepository(
      gateway: FakeThumbnailGateway(),
      queue: ThumbnailQueue(),
      metadata: metadata,
      paths: paths,
      logger: memoryLogger(sink),
    );
    expect(
      thirdLaunch.cachedFile(_clip(5), stamp: _stamp, tier: ThumbnailTier.cell),
      isNull,
    );
    await thirdLaunch.load();
    expect(
      thirdLaunch.cachedFile(_clip(5), stamp: _stamp, tier: ThumbnailTier.cell),
      made,
    );
    expect(
      thirdLaunch.cachedFile(
        _clip(5),
        stamp: _stamp,
        tier: ThumbnailTier.poster,
      ),
      isNull,
    );

    // A frame that cannot be extracted.
    {
      gateway.failingVideos.add(paths.absoluteFromVideos(_clip(5).relPath));

      final String? file = await thumbnails
          .request(
            _clip(5),
            stamp: _stamp,
            tier: ThumbnailTier.poster,
            orientation: _landscape,
          )
          .file;

      expect(file, isNull);
      expect(
        sink.lines.single,
        startsWith(
          '[WARNING] 2024-01-05 10:00:00.000: [THUMBNAILS] Could not make the '
          'poster thumbnail of Profiles/Work/2024-01-05.mp4',
        ),
      );
    }
  });

  test('generates at most three thumbnails at once (the plugin runs every '
      'call on an unbounded thread pool, each holding a decoder)', () async {
    gateway.holdRequests = true;
    for (int day = 1; day <= 10; day++) {
      thumbnails.request(
        _clip(day),
        stamp: _stamp,
        tier: ThumbnailTier.cell,
        orientation: _landscape,
      );
    }
    await eventually(() => gateway.inFlight == 3);
    await _settle(); // time for a fourth to start, were the bound broken
    expect(gateway.inFlight, 3);

    await _freeSlotsOneByOne(gateway, until: 5);
    await _settle();
    expect(gateway.inFlight, 3);
    // Which were started: the first three (together, so in any order), then
    // the two latest waiting.
    final List<String> started = <String>[
      for (final ThumbnailRequest request in gateway.requests)
        request.videoPath,
    ];
    expect(
      started.take(3),
      unorderedEquals(<String>[
        for (final int day in <int>[1, 2, 3])
          paths.absoluteFromVideos(_clip(day).relPath),
      ]),
    );
    expect(started.skip(3), <String>[
      for (final int day in <int>[10, 9])
        paths.absoluteFromVideos(_clip(day).relPath),
    ]);
  });

  test('a request cancelled before it starts is never generated (a tile '
      'scrolled away)', () async {
    gateway.holdRequests = true;
    for (int day = 1; day <= 3; day++) {
      thumbnails.request(
        _clip(day),
        stamp: _stamp,
        tier: ThumbnailTier.cell,
        orientation: _landscape,
      );
    }
    final ThumbnailTicket scrolledAway = thumbnails.request(
      _clip(4),
      stamp: _stamp,
      tier: ThumbnailTier.cell,
      orientation: _landscape,
    );
    await eventually(() => gateway.inFlight == 3);

    scrolledAway.cancel();
    gateway.completePending();
    await eventually(() => gateway.inFlight == 0);
    await _settle();

    expect(await scrolledAway.file, isNull);
    expect(
      gateway.requests.map((ThumbnailRequest request) => request.videoPath),
      isNot(contains(paths.absoluteFromVideos(_clip(4).relPath))),
    );
  });

  group('carryOver', () {
    const FileStamp rewritten = FileStamp(
      sizeBytes: 9,
      modifiedMs: 1704452400000,
    );

    test('a clip rewritten in place with the same frames (a subtitle edit) '
        'keeps its thumbnails under its new stamp, with nothing generated '
        'again', () async {
      for (final ThumbnailTier tier in ThumbnailTier.values) {
        await thumbnails
            .request(
              _clip(5),
              stamp: _stamp,
              tier: tier,
              orientation: _landscape,
            )
            .file;
      }
      final int generated = gateway.requests.length;

      await thumbnails.carryOver(_clip(5), from: _stamp, to: rewritten);

      for (final ThumbnailTier tier in ThumbnailTier.values) {
        final String? file = thumbnails.cachedFile(
          _clip(5),
          stamp: rewritten,
          tier: tier,
        );
        expect(file, isNotNull, reason: tier.name);
        expect(File(file!).existsSync(), isTrue, reason: tier.name);
        expect(
          thumbnails.cachedFile(_clip(5), stamp: _stamp, tier: tier),
          isNull,
          reason: 'the old version is gone',
        );
      }
      expect(gateway.requests, hasLength(generated));
    });
  });

  group('backfill', () {
    ClipIndex indexOf(Iterable<int> days) => ClipIndex(
      profile: _work,
      clips: <IndexedClip>[
        for (final int day in days) IndexedClip(ref: _clip(day), stamp: _stamp),
      ],
    );

    String videoOf(int day) => paths.absoluteFromVideos(_clip(day).relPath);

    test('never takes the last slot: a tile on screen starts at once, even '
        'while the backfill is busy (review 1b)', () async {
      gateway.holdRequests = true;
      thumbnails.backfill(
        indexOf(<int>[for (int day = 1; day <= 10; day++) day]),
        tier: ThumbnailTier.cell,
        orientation: _landscape,
      );
      await _settle();

      thumbnails.request(
        _clip(20),
        stamp: _stamp,
        tier: ThumbnailTier.cell,
        orientation: _landscape,
      );
      await eventually(
        () => gateway.requests.any(
          (ThumbnailRequest request) => request.videoPath == videoOf(20),
        ),
      );

      expect(gateway.inFlight, 3);
    });

    test('a snapshot fed again queues only what changed, and a queued clip '
        'rewritten or deleted since is dropped (review 1b)', () async {
      gateway.holdRequests = true;
      final ClipIndex first = indexOf(<int>[1, 2, 3, 4, 5]);
      thumbnails.backfill(
        first,
        tier: ThumbnailTier.cell,
        orientation: _landscape,
      );
      await eventually(() => gateway.inFlight == 2); // 5 and 4
      const FileStamp rewritten = FileStamp(
        sizeBytes: 9,
        modifiedMs: 1704448900000,
      );
      final ClipIndex second = first
          .withClip(IndexedClip(ref: _clip(2), stamp: rewritten))
          .withoutClip(_clip(3).relPath)
          .withClip(IndexedClip(ref: _clip(6), stamp: _stamp));

      thumbnails.backfill(
        second,
        tier: ThumbnailTier.cell,
        orientation: _landscape,
      );
      await _freeSlotsOneByOne(gateway, until: 5);
      await _settle();

      expect(
        gateway.requests.skip(2).map((ThumbnailRequest r) => r.videoPath),
        <String>[videoOf(1), videoOf(6), videoOf(2)],
      );
      expect(gateway.requests.last.outputPath, contains('_1704448900000_9_'));
    });
  });
}

/// Gives queued work a chance to run (for asserting that something did
/// NOT happen; use [eventually] to wait for something that must).
Future<void> _settle() => pumpEventQueue(times: 50);

/// Lets the oldest held generation finish, waits for the job that takes
/// its slot to reach [gateway], and repeats until [until] generations were
/// asked for.
///
/// Why one at a time: every job checks the disk (`File.exists`) before it
/// calls the gateway, and that IO completes on the VM's IO threads, so jobs
/// that start together reach the gateway in whichever order the file system
/// answers. Freeing one slot at a time starts one job at a time, which makes
/// the order of `requests` the order the repository started them.
Future<void> _freeSlotsOneByOne(
  FakeThumbnailGateway gateway, {
  required int until,
}) async {
  while (gateway.requests.length < until) {
    final int asked = gateway.requests.length;
    gateway.completePending(count: 1);
    await eventually(() => gateway.requests.length > asked);
  }
}
