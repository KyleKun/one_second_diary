import 'dart:async';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_meta_of_probe.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Fills the [ClipMetadataCache] for clips it knows nothing about: clips from
/// older installs, and clips added or changed outside the app. Clips the app
/// saves never need it.
///
/// A low-priority, serial queue:
/// - it awaits ONE `MediaEngine.probe` at a time, plus one `readSubtitles`
///   only when the probe found a subtitle stream, plus one `probeKeyframes`,
///   so a user's save or movie waits behind at most one background job; a
///   failed keyframe probe is logged and the other facts are kept;
/// - a clip cached WITHOUT keyframes is queued for a keyframe-only pass,
///   worked after every full probe;
/// - each [enqueue]d snapshot is worked newest clip first, snapshots in the
///   order they arrive;
/// - [pause] and [resume] bracket recording, saving and making a movie: the
///   probe in flight finishes, and nothing else starts;
/// - a clip whose probe fails is logged and skipped until its file changes;
/// - results are saved at most every [_flushInterval] and when the queue
///   drains; the app also calls `ClipMetadataCache.flush()` when it goes to
///   the background.
///
/// Load the cache before the first [enqueue], or every clip is probed again.
/// Not final so tests can fake it.
class ClipMetadataBackfill {
  ClipMetadataBackfill({
    required this._engine,
    required this._cache,
    required this._paths,
    required this._logger,
    required this._clock,
  });

  final MediaEngine _engine;
  final ClipMetadataCache _cache;
  final AppPaths _paths;
  final AppLogger _logger;
  final Clock _clock;

  /// How often a long backfill saves what it learnt. Each save rewrites the
  /// whole sidecar (25-42 ms of background CPU at 5 000 clips), so saving
  /// every few probes would cost O(N²) over a first backfill. A crash loses
  /// at most this much probing.
  static const Duration _flushInterval = Duration(seconds: 30);

  /// How often a long backfill tells [progress]: the Journey tab counts its
  /// estimate again each time, over the whole index.
  static const Duration _progressInterval = Duration(seconds: 1);
  static const String _tag = 'CLIP_META';

  final StreamController<void> _progress = StreamController<void>.broadcast();

  /// Clips waiting, by relPath, in work order.
  final Map<String, _Job> _queue = <String, _Job>{};

  /// Clips cached without keyframes, waiting for the keyframe-only pass,
  /// by relPath, in work order; worked once [_queue] is empty.
  final Map<String, _Job> _keyframeQueue = <String, _Job>{};

  /// The clip being probed.
  _Job? _inFlight;

  /// Clips (with the stamp they had) whose probe failed this session.
  final Set<_Job> _failed = <_Job>{};

  /// The last snapshot [enqueue] saw, per profile.
  final Map<ProfileKey, ClipIndex> _seen = <ProfileKey, ClipIndex>{};

  /// The drain loop, while there is work.
  Future<void>? _running;

  /// Outstanding [pause] calls.
  int _pauses = 0;

  /// Completed by the [resume] that ends the last pause.
  Completer<void>? _resumed;

  bool _disposed = false;

  /// Queues every clip of [index] whose metadata is not cached for its
  /// current stamp, newest first, and every cached clip whose keyframes are
  /// not, for the keyframe-only pass. A clip already queued keeps its place
  /// (with the stamp of this snapshot).
  ///
  /// Fed every snapshot of every profile (each save, delete and rescan).
  /// After a profile's first snapshot only the clips changed since the
  /// previous one are looked at ([ClipIndex.changedSince]), so a save costs
  /// the UI isolate its own clip, not a pass over all of them.
  void enqueue(ClipIndex index) {
    if (_disposed) return;
    final ClipIndex? previous = _seen[index.profile];
    _seen[index.profile] = index;
    for (final ClipRef clip
        in previous == null
            ? index.newestFirst
            : index.changedSince(previous)) {
      final FileStamp stamp = index.stampOf(clip)!;
      final ClipMeta? cached = _cache.lookup(
        relPath: clip.relPath,
        stamp: stamp,
      );
      if (cached != null && _complete(cached)) continue;
      final _Job job = _Job(
        clip,
        stamp,
        keyframesOnly: cached != null && _hasFormatFacts(cached),
      );
      if (job == _inFlight || _failed.contains(job)) continue;
      (job.keyframesOnly ? _keyframeQueue : _queue)[clip.relPath] = job;
    }
    if (_queue.isNotEmpty || _keyframeQueue.isNotEmpty) {
      _running ??= _drain();
    }
  }

  /// Stops starting probes until every [pause] has its [resume]; the probe
  /// in flight finishes. Pauses nest, so overlapping phases (recording,
  /// then saving) each pause and resume once.
  void pause() => _pauses++;

  /// Ends one [pause].
  void resume() {
    if (_pauses == 0) return;
    _pauses--;
    if (_pauses == 0) {
      _resumed?.complete();
      _resumed = null;
    }
  }

  /// Fires during a run, at most every [_progressInterval], when clips'
  /// metadata was learnt since the last time (the Journey tab's "About …"
  /// estimate follows a long first backfill). The end of a run is
  /// [whenIdle].
  Stream<void> get progress => _progress.stream;

  /// Completes when the queue is empty, no probe runs and what was learnt
  /// is saved. Never while paused with work or an unsaved result left. A
  /// run that starts right after (an enqueue at the end of a drain) is
  /// another future: a caller that must see the end of every run checks
  /// [isRunning] again.
  Future<void> get whenIdle => _running ?? Future<void>.value();

  /// Whether a run is on (the queue is not empty, or a probe or save is).
  bool get isRunning => _running != null;

  /// Drops the queue and waits for the probe in flight.
  Future<void> dispose() async {
    _disposed = true;
    _queue.clear();
    _keyframeQueue.clear();
    _resumed?.complete();
    _resumed = null;
    await whenIdle;
    await _progress.close();
  }

  /// Completes at once unless paused; otherwise at the resume that ends the
  /// last pause, or at [dispose].
  Future<void> _untilResumed() async {
    while (_pauses > 0 && !_disposed) {
      await (_resumed ??= Completer<void>()).future;
    }
  }

  /// Probes the queue, then saves. Waits out every pause first, the final
  /// save included: a save spawns an isolate that would compete with a
  /// recording.
  Future<void> _drain() async {
    try {
      DateTime lastFlush = _clock.now();
      DateTime lastProgress = lastFlush;
      while (true) {
        await _untilResumed();
        final Map<String, _Job> queue = _queue.isNotEmpty
            ? _queue
            : _keyframeQueue;
        if (queue.isEmpty) break;
        final _Job job = queue.remove(queue.keys.first)!;
        final ClipMeta? cached = _cache.lookup(
          relPath: job.clip.relPath,
          stamp: job.stamp,
        );
        // Written through since it was queued: a save publishes its clip
        // to the index before it writes the clip's facts; or the entry the
        // keyframe-only pass was to complete is gone or complete.
        if (job.keyframesOnly
            ? cached == null || cached.keyframes != null
            : cached != null && _hasFormatFacts(cached)) {
          continue;
        }
        _inFlight = job;
        await (job.keyframesOnly
            ? _backfillKeyframes(job, cached!)
            : _backfill(job));
        _inFlight = null;
        if (_clock.now().difference(lastProgress) >= _progressInterval) {
          lastProgress = _clock.now();
          if (!_progress.isClosed) _progress.add(null);
        }
        if (_pauses == 0 &&
            _clock.now().difference(lastFlush) >= _flushInterval) {
          await _cache.flush();
          lastFlush = _clock.now();
        }
      }
      await _cache.flush();
    } finally {
      _inFlight = null;
      _running = null;
    }
  }

  Future<void> _backfill(_Job job) async {
    final String path = _paths.absoluteFromVideos(job.clip.relPath);
    try {
      final ClipProbe probe = await _engine.probe(path);
      String subtitles = '';
      if (probe.hasSubtitleStream) {
        // The subtitle read is a second ffmpeg session: a pause that came
        // while the probe ran holds it back too.
        await _untilResumed();
        if (_disposed) return;
        subtitles = await _engine.readSubtitles(path);
      }
      // The facts are written before the keyframe probe, a third session
      // that a pause holds back too: a pause (or a dispose) in between
      // leaves a clip read without keyframes, which the keyframe-only pass
      // completes later.
      final ClipMeta meta = clipMetaOfProbe(probe, subtitleText: subtitles);
      _cache.put(relPath: job.clip.relPath, stamp: job.stamp, meta: meta);
      await _untilResumed();
      if (_disposed) return;
      await _backfillKeyframes(job, meta);
    } on AppException catch (error, stackTrace) {
      _failed.add(job);
      _logger.warning(
        _tag,
        'Could not read the metadata of ${job.clip.relPath}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Whether [meta] needs no pass at all: its keyframes and the format facts
  /// are there.
  static bool _complete(ClipMeta meta) =>
      meta.keyframes != null && _hasFormatFacts(meta);

  /// Whether [meta] was written with the format facts (`fps`, `channels`,
  /// `pixelFormat`, `colorTransfer`, `schema`). The schema is known once a clip
  /// was probed (`ClipSchema.other` at worst), so an entry without it is read
  /// once more, whole; the other facts may be null for a clip that has none.
  static bool _hasFormatFacts(ClipMeta meta) => meta.schema != null;

  /// The keyframe-only pass: completes [cached] with the clip's keyframes.
  /// A failed probe is logged and skipped like a failed full probe.
  Future<void> _backfillKeyframes(_Job job, ClipMeta cached) async {
    final ClipKeyframes? keyframes = await _keyframes(job);
    if (keyframes == null) return;
    _cache.put(
      relPath: job.clip.relPath,
      stamp: job.stamp,
      meta: cached.withKeyframes(keyframes),
    );
  }

  /// The clip's keyframes, or null when the probe fails: logged, and the
  /// keyframe-only job is marked failed so the clip is not asked again
  /// until its file changes or the next launch.
  Future<ClipKeyframes?> _keyframes(_Job job) async {
    try {
      return await _engine.probeKeyframes(
        _paths.absoluteFromVideos(job.clip.relPath),
      );
    } on AppException catch (error, stackTrace) {
      _failed.add(_Job(job.clip, job.stamp, keyframesOnly: true));
      _logger.warning(
        _tag,
        'Could not read the keyframes of ${job.clip.relPath}',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}

/// One clip to probe, as the queuing snapshot saw it: everything, or only
/// its keyframes ([keyframesOnly], a clip cached without them).
final class _Job {
  const _Job(this.clip, this.stamp, {required this.keyframesOnly});

  final ClipRef clip;
  final FileStamp stamp;
  final bool keyframesOnly;

  @override
  bool operator ==(Object other) =>
      other is _Job &&
      other.clip == clip &&
      other.stamp == stamp &&
      other.keyframesOnly == keyframesOnly;

  @override
  int get hashCode => Object.hash(clip, stamp, keyframesOnly);
}
