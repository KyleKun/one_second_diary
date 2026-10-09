import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/osd_artist.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_backfill.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/held_media_engine.dart';
import '../../../support/track_1b/saving_clip_metadata_cache.dart';

const ProfileKey _default = ProfileKey.defaultProfile;
const FileStamp _stamp = FileStamp(sizeBytes: 8, modifiedMs: 1);

ClipProbe _probe({int durationMs = 1000, bool subtitles = false}) => ClipProbe(
  durationMs: durationMs,
  hasAudio: true,
  hasSubtitleStream: subtitles,
  artist: osdArtist,
  album: 'Default',
  comment: 'origin=osd_recording',
  locationTag: null,
  title: null,
  width: 1920,
  height: 1080,
  codec: 'h264',
  fps: 30,
);

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late HeldMediaEngine engine;
  late ClipMetadataCache cache;
  late ClipMetadataBackfill backfill;

  /// A fresh diary, engine, cache and backfill (also for a second scenario
  /// inside one test).
  Future<void> open() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    engine = HeldMediaEngine(scratchDir: paths.scratchDir);
    cache = ClipMetadataCache(paths: paths, logger: memoryLogger(sink));
    backfill = ClipMetadataBackfill(
      engine: engine,
      cache: cache,
      paths: paths,
      logger: memoryLogger(sink),
      clock: FakeClock(DateTime(2024, 1, 5, 10)),
    );
    addTearDown(backfill.dispose);
  }

  setUp(open);

  /// An index of clips on consecutive days from 2024-01-01; each gets a
  /// scripted probe of [durationMs] + its position.
  ClipIndex seed(int count, {int durationMs = 1000, bool subtitles = false}) {
    final List<IndexedClip> clips = <IndexedClip>[];
    for (int i = 0; i < count; i++) {
      final String relPath = ClipNameCodec.format(
        LocalDay(2024, 1, 1).addDays(i),
      );
      clips.add(
        IndexedClip(
          ref: ClipRef(profile: _default, relPath: relPath),
          stamp: _stamp,
        ),
      );
      engine.probes[paths.absoluteFromVideos(relPath)] = _probe(
        durationMs: durationMs + i,
        subtitles: subtitles,
      );
    }
    return ClipIndex(profile: _default, clips: clips);
  }

  String abs(String relPath) => paths.absoluteFromVideos(relPath);

  test('probes every clip without metadata, newest first, reads subtitles '
      'only from clips with a subtitle stream, skips clips already cached for '
      'their stamp, and caches what it learns; a clip whose probe fails is '
      'logged and skipped until its file changes', () async {
    final ClipIndex index = seed(4);
    engine.probes[abs('2024-01-02.mp4')] = _probe(
      durationMs: 1001,
      subtitles: true,
    );
    engine.subtitles[abs('2024-01-02.mp4')] = 'Walk around Asakusa';
    cache.put(
      relPath: '2024-01-03.mp4',
      stamp: _stamp,
      meta: const ClipMeta(durationMs: 7, schema: ClipSchema.v15),
    );

    backfill.enqueue(index);
    await backfill.whenIdle;

    expect(engine.probedPaths, <String>[
      abs('2024-01-04.mp4'),
      abs('2024-01-02.mp4'),
      abs('2024-01-01.mp4'),
    ]);
    expect(engine.subtitleReads, <String>[abs('2024-01-02.mp4')]);
    expect(
      cache.lookup(relPath: '2024-01-03.mp4', stamp: _stamp)?.durationMs,
      7,
    );
    expect(
      cache.lookup(relPath: '2024-01-01.mp4', stamp: _stamp),
      const ClipMeta(
        durationMs: 1000,
        hasAudio: true,
        hasSubtitleStream: false,
        subtitleText: '',
        locationText: '',
        isOsdV15: true,
        width: 1920,
        height: 1080,
        codec: 'h264',
        origin: ClipOrigin.osdRecording,
      ),
    );
    expect(
      cache.lookup(relPath: '2024-01-02.mp4', stamp: _stamp)?.subtitleText,
      'Walk around Asakusa',
    );

    // A clip whose probe fails, in a fresh diary.
    {
      await open();
      final ClipIndex index = seed(3);
      engine.probes.remove(abs('2024-01-02.mp4')); // the probe throws

      backfill.enqueue(index);
      await backfill.whenIdle;
      backfill.enqueue(index);
      await backfill.whenIdle;

      expect(cache.lookup(relPath: '2024-01-01.mp4', stamp: _stamp), isNotNull);
      expect(cache.lookup(relPath: '2024-01-02.mp4', stamp: _stamp), isNull);
      expect(engine.probedPaths, <String>[
        abs('2024-01-03.mp4'),
        abs('2024-01-02.mp4'),
        abs('2024-01-01.mp4'),
      ]);
      expect(
        sink.lines,
        contains(
          allOf(
            startsWith('[WARNING] '),
            contains(
              '[CLIP_META] Could not read the metadata of 2024-01-02.mp4',
            ),
            contains('VideoProcessingException'),
          ),
        ),
      );

      const FileStamp rewritten = FileStamp(sizeBytes: 9, modifiedMs: 2);
      engine.probes[abs('2024-01-02.mp4')] = _probe();
      backfill.enqueue(
        index.withClip(
          IndexedClip(
            ref: ClipRef(profile: _default, relPath: '2024-01-02.mp4'),
            stamp: rewritten,
          ),
        ),
      );
      await backfill.whenIdle;
      expect(
        cache.lookup(relPath: '2024-01-02.mp4', stamp: rewritten),
        isNotNull,
      );
    }
  });

  // Where a clip can be cut for a movie with transitions, one more ffprobe
  // per clip. A diary read by an earlier version has every clip cached
  // without them: the keyframe-only pass completes those entries, after
  // the full probes, so the confirmation's "older clips" count comes right
  // over time without reading the clips again.
  // The sidecar also holds fps, channels, pixel format, colour
  // transfer and the schema. An entry written before them has no schema
  // (a probed clip always has one), so it is read once more, whole, not
  // only for its keyframes.
  test('an entry cached before the format facts (no schema) is probed once '
      'more, whole, so older sidecars gain the facts', () async {
    final ClipIndex index = seed(2);
    cache.put(
      relPath: '2024-01-01.mp4',
      stamp: _stamp,
      meta: const ClipMeta(durationMs: 7),
    );

    backfill.enqueue(index);
    await backfill.whenIdle;

    expect(engine.probedPaths, <String>[
      abs('2024-01-02.mp4'),
      abs('2024-01-01.mp4'),
    ]);
    final ClipMeta? read = cache.lookup(
      relPath: '2024-01-01.mp4',
      stamp: _stamp,
    );
    expect(read?.durationMs, 1000);
    expect(read?.schema, ClipSchema.v15);
    expect(read?.fps, 30);
  });

  test('reads the keyframes of every clip it probes (one keyframe probe per '
      'clip, after its facts are written), keeps the facts of a clip whose '
      'keyframe probe fails, and completes clips cached without keyframes '
      'in a keyframe-only pass after the full probes, which a pause holds '
      'back', () async {
    const ClipKeyframes ready = ClipKeyframes(
      frameCount: 45,
      indices: <int>[0, 10, 35],
    );
    const ClipKeyframes old = ClipKeyframes(frameCount: 30, indices: <int>[0]);
    final ClipIndex index = seed(3);
    engine.keyframes[abs('2024-01-03.mp4')] = ready;
    // 2024-01-02: its keyframe probe throws (not scripted).
    // 2024-01-01: cached by an earlier version, without keyframes.
    cache.put(
      relPath: '2024-01-01.mp4',
      stamp: _stamp,
      meta: const ClipMeta(durationMs: 7, tags: <String>['bread']),
    );
    engine.keyframes[abs('2024-01-01.mp4')] = old;

    backfill.enqueue(index);
    await backfill.whenIdle;

    expect(engine.probedPaths, <String>[
      abs('2024-01-03.mp4'),
      abs('2024-01-02.mp4'),
    ]);
    expect(engine.keyframesProbedPaths, <String>[
      abs('2024-01-03.mp4'),
      abs('2024-01-02.mp4'),
      abs('2024-01-01.mp4'), // the keyframe-only pass, after the full ones
    ]);
    expect(
      cache.lookup(relPath: '2024-01-03.mp4', stamp: _stamp)?.keyframes,
      ready,
    );
    final ClipMeta? failed = cache.lookup(
      relPath: '2024-01-02.mp4',
      stamp: _stamp,
    );
    expect(failed?.durationMs, 1001);
    expect(failed?.keyframes, isNull);
    expect(
      sink.lines,
      contains(
        allOf(
          startsWith('[WARNING] '),
          contains(
            '[CLIP_META] Could not read the keyframes of 2024-01-02.mp4',
          ),
        ),
      ),
    );
    expect(
      cache.lookup(relPath: '2024-01-01.mp4', stamp: _stamp),
      const ClipMeta(durationMs: 7, tags: <String>['bread'], keyframes: old),
      reason: 'merged into the entry, which keeps its other facts',
    );

    // A pause holds the keyframe-only pass back like any probe.
    {
      await open();
      final ClipIndex index = seed(1);
      cache.put(
        relPath: '2024-01-01.mp4',
        stamp: _stamp,
        meta: const ClipMeta(durationMs: 7),
      );
      engine.keyframes[abs('2024-01-01.mp4')] = old;

      backfill.pause();
      backfill.enqueue(index);
      await pumpEventQueue();
      expect(engine.keyframesProbedPaths, isEmpty);

      backfill.resume();
      await backfill.whenIdle;
      expect(engine.keyframesProbedPaths, <String>[abs('2024-01-01.mp4')]);
      expect(engine.probedPaths, isEmpty);
      expect(
        cache.lookup(relPath: '2024-01-01.mp4', stamp: _stamp)?.keyframes,
        old,
      );
    }
  });

  Future<void> untilHeld(int probes) async {
    while (engine.heldProbes < probes) {
      await pumpEventQueue(times: 1);
    }
  }

  test('awaits one probe at a time, so a user job waits behind at most one '
      '(CONTRACTS §4 Media); a clip whose facts were written through after it '
      'was queued is not probed', () async {
    final ClipIndex index = seed(3);
    engine.hold = true;

    backfill.enqueue(index);
    await untilHeld(1);
    await pumpEventQueue();
    expect(engine.probedPaths, <String>[abs('2024-01-03.mp4')]);

    backfill.enqueue(index); // a new snapshot while the probe runs
    engine.hold = false;
    engine.releaseProbe();
    await backfill.whenIdle;

    expect(engine.mostInFlight, 1);
    expect(engine.probedPaths, <String>[
      abs('2024-01-03.mp4'),
      abs('2024-01-02.mp4'),
      abs('2024-01-01.mp4'),
    ]);

    // A clip whose facts were written through after it was queued (the save
    // flow's write racing the snapshot it published) is not probed.
    {
      await open();
      final ClipIndex index = seed(2);
      engine.hold = true;
      backfill.enqueue(index);
      await untilHeld(1); // 2024-01-02 probing, 2024-01-01 queued

      cache.put(
        relPath: '2024-01-01.mp4',
        stamp: _stamp,
        meta: const ClipMeta(durationMs: 7),
      );
      engine.hold = false;
      engine.releaseProbe();
      await backfill.whenIdle;

      expect(engine.probedPaths, <String>[abs('2024-01-02.mp4')]);
      expect(
        cache.lookup(relPath: '2024-01-01.mp4', stamp: _stamp)?.durationMs,
        7,
      );
    }
  });

  test('pause lets the probe in flight finish (its subtitle read, a second '
      'ffmpeg session, waits too) and starts no other until every pause is '
      'resumed; a clip queued while paused waits too', () async {
    final ClipIndex index = seed(3);
    engine.hold = true;
    backfill.enqueue(index);
    await untilHeld(1);

    backfill
      ..pause() // recording
      ..pause(); // saving, overlapping it
    engine.hold = false;
    engine.releaseProbe();
    await pumpEventQueue();
    expect(cache.lookup(relPath: '2024-01-03.mp4', stamp: _stamp), isNotNull);
    expect(engine.probedPaths, <String>[abs('2024-01-03.mp4')]);

    backfill.resume();
    await pumpEventQueue();
    expect(engine.probedPaths, <String>[abs('2024-01-03.mp4')]);

    backfill.resume();
    await backfill.whenIdle;
    expect(engine.probedPaths, <String>[
      abs('2024-01-03.mp4'),
      abs('2024-01-02.mp4'),
      abs('2024-01-01.mp4'),
    ]);

    // A clip queued while paused waits for the resume.
    backfill.pause();
    final ClipIndex later = index.withClip(
      IndexedClip(
        ref: ClipRef(profile: _default, relPath: '2024-01-09.mp4'),
        stamp: _stamp,
      ),
    );
    engine.probes[abs('2024-01-09.mp4')] = _probe();
    backfill.enqueue(later);
    await pumpEventQueue();
    expect(engine.probedPaths, hasLength(3));

    backfill.resume();
    await backfill.whenIdle;
    expect(engine.probedPaths.last, abs('2024-01-09.mp4'));

    // A pause during a probe also holds back that clip's subtitle read until
    // the resume.
    {
      await open();
      final ClipIndex index = seed(1, subtitles: true);
      engine.subtitles[abs('2024-01-01.mp4')] = 'Asakusa';
      engine.hold = true;
      backfill.enqueue(index);
      await untilHeld(1);

      backfill.pause(); // recording starts
      engine.hold = false;
      engine.releaseProbe();
      await pumpEventQueue();
      expect(engine.subtitleReads, isEmpty);

      backfill.resume();
      await backfill.whenIdle;
      expect(engine.subtitleReads, <String>[abs('2024-01-01.mp4')]);
      expect(
        cache.lookup(relPath: '2024-01-01.mp4', stamp: _stamp)?.subtitleText,
        'Asakusa',
      );
    }
  });

  group('saving (review 1b: every 25 probes rewrote the whole sidecar, '
      'O(N²) over a first backfill)', () {
    late FakeClock clock;
    late SavingClipMetadataCache saving;
    late ClipMetadataBackfill timed;

    void openTimed() {
      clock = FakeClock(DateTime(2024, 1, 5, 10));
      saving = SavingClipMetadataCache(
        paths: paths,
        logger: memoryLogger(sink),
      );
      timed = ClipMetadataBackfill(
        engine: engine,
        cache: saving,
        paths: paths,
        logger: memoryLogger(sink),
        clock: clock,
      );
      addTearDown(timed.dispose);
    }

    setUp(openTimed);

    Set<String> firstDays(int count) => <String>{
      for (int i = 0; i < count; i++)
        ClipNameCodec.format(LocalDay(2024, 1, 1).addDays(i)),
    };

    test('a long backfill saves every 30 s and when it drains, not every few '
        'clips, and never while paused (a save spawns an isolate during a '
        'recording)', () async {
      final ClipIndex index = seed(40);
      engine.hold = true;
      timed.enqueue(index);
      for (int i = 0; i < 30; i++) {
        await untilHeld(1);
        engine.releaseProbe();
      }
      await untilHeld(1); // 30 clips learnt, the 31st probing
      expect(saving.saved, isEmpty);

      clock.advance(const Duration(seconds: 30));
      engine.releaseProbe();
      await untilHeld(1);
      // Newest first: the 31 latest days.
      expect(saving.saved, firstDays(40).skip(9).toSet());

      engine.hold = false;
      engine.releaseProbe();
      await timed.whenIdle;
      expect(saving.saved, firstDays(40));

      // Never saves while paused; the drained queue saves after the resume.
      {
        await open();
        openTimed();
        final ClipIndex index = seed(1);
        engine.hold = true;
        timed.enqueue(index);
        await untilHeld(1);

        timed.pause();
        engine.hold = false;
        engine.releaseProbe();
        await pumpEventQueue();
        expect(
          cache.lookup(relPath: '2024-01-01.mp4', stamp: _stamp),
          isNull,
        ); // other cache
        expect(
          saving.lookup(relPath: '2024-01-01.mp4', stamp: _stamp),
          isNotNull,
        );
        expect(saving.saved, isEmpty);

        timed.resume();
        await timed.whenIdle;
        expect(saving.saved, <String>{'2024-01-01.mp4'});
      }
    });

    // The Journey's "About …" estimate follows a long backfill.
    test('a long backfill tells what it learnt at most once a second; its '
        'end is whenIdle', () async {
      final List<int> heard = <int>[];
      timed.progress.listen(
        (_) => heard.add(
          firstDays(3)
              .where(
                (String relPath) =>
                    saving.lookup(relPath: relPath, stamp: _stamp) != null,
              )
              .length,
        ),
      );
      engine.hold = true;
      timed.enqueue(seed(3));
      await untilHeld(1);
      engine.releaseProbe(); // the 3rd learnt, within the second
      await untilHeld(1);
      expect(heard, isEmpty);

      clock.advance(const Duration(seconds: 1));
      engine.releaseProbe(); // the 2nd learnt, a second in
      await untilHeld(1);
      await pumpEventQueue();
      expect(heard, <int>[2], reason: 'the two newest clips are learnt');

      engine.hold = false;
      engine.releaseProbe();
      await timed.whenIdle;
      await pumpEventQueue();
      expect(heard, <int>[2]);
    });
  });
}
