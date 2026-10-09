// Muting a saved clip: one probe for the notes, the remux
// with the silent track into the clip's place, the cache marked muted with
// its other facts kept; a muted clip is never rewritten again; a failure
// leaves the clip as it was.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/osd_artist.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_audio.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_queue.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/scripted_media_store_gateway.dart';

const ProfileKey _work = ProfileKey('Work');
final LocalDay _day = LocalDay(2024, 1, 5);

/// The bytes of the clip as the user saved it (the remux writes others).
const List<int> _original = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9];

ClipProbe _probe({String? synopsis}) => ClipProbe(
  durationMs: 2000,
  hasAudio: true,
  hasSubtitleStream: true,
  artist: osdArtist,
  album: 'Work',
  comment: 'origin=osd_recording',
  locationTag: null,
  title: null,
  width: 1920,
  height: 1080,
  codec: 'h264',
  fps: 30,
  synopsis: synopsis,
);

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late ScriptedMediaStoreGateway gallery;
  late FakeMediaEngine engine;
  late ClipRepository repository;
  late ClipMetadataCache metadata;
  late ClipAudio audio;
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
    audio = ClipAudio(
      engine: engine,
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
    );
    file = await seedClip(paths, _work, _day, bytes: _original);
    clip = ClipRef(profile: _work, relPath: paths.relativeToVideos(file.path));
    await repository.loadAll(active: _work, profiles: <ProfileKey>[]);
    engine.probes[file.path] = _probe(synopsis: 'place=Home');
  });

  FileStamp stampNow() => repository.snapshotOf(_work)!.stampOf(clip)!;

  /// What the backfill would have cached for the clip as it is on disk.
  void cache({bool? isMuted, int? durationMs = 1500}) => metadata.put(
    relPath: clip.relPath,
    stamp: stampNow(),
    meta: ClipMeta(
      durationMs: durationMs,
      hasAudio: true,
      hasSubtitleStream: true,
      subtitleText: 'Old text',
      locationText: 'Home',
      isOsdV15: true,
      width: 1920,
      height: 1080,
      codec: 'h264',
      isMuted: isMuted,
    ),
  );

  test('mutes the clip: one probe for its notes, the remux with a silent '
      'track as long as the cached length (the probed one when unknown) '
      'into the clip\'s place, the cache marked muted with its other facts '
      'kept; a muted clip is never rewritten again', () async {
    cache();
    final FileStamp before = stampNow();
    expect(audio.isMuted(clip), isFalse);

    await audio.mute(clip);

    expect(engine.probedPaths, <String>[file.path]);
    expect(engine.muteRequests.single, (
      clipPath: file.path,
      durationMs: 1500,
      synopsis: 'place=Home',
    ));
    expect(file.readAsBytesSync(), fakeVideoBytes);
    expect(stampNow(), isNot(before));
    final ClipMeta? meta = metadata.lookup(
      relPath: clip.relPath,
      stamp: stampNow(),
    );
    expect(meta?.isMuted, isTrue);
    expect(meta?.hasAudio, isTrue);
    expect(meta?.subtitleText, 'Old text');
    expect(meta?.locationText, 'Home');
    expect(audio.isMuted(clip), isTrue);
    expect(sink.lines.last, contains('[MUTE] Muted ${clip.relPath}'));

    // Muted already: nothing to do.
    await audio.mute(clip);
    expect(engine.muteRequests, hasLength(1));

    // A length the cache does not know comes from the probe.
    cache(durationMs: null);
    await audio.mute(clip);
    expect(engine.muteRequests.last.durationMs, 2000);
  });

  test('a mute that fails is logged and thrown, and the clip is as it was; '
      'the gallery refusing the new file is the same', () async {
    cache();
    engine.muteError = const VideoProcessingException(
      'ffmpeg failed',
      returnCode: 1,
      logTail: '',
    );

    await expectLater(
      audio.mute(clip),
      throwsA(isA<VideoProcessingException>()),
    );

    expect(file.readAsBytesSync(), _original);
    expect(audio.isMuted(clip), isFalse);
    expect(sink.lines.last, contains('[MUTE] Could not mute'));

    engine.muteError = null;
    gallery.publishResults.add(false);

    await expectLater(audio.mute(clip), throwsA(isA<MediaStoreException>()));

    expect(file.readAsBytesSync(), _original);
    expect(audio.isMuted(clip), isFalse);
  });
}
