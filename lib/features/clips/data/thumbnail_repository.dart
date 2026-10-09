import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/thumbnail_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_queue.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_ticket.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/thumbnail_tier.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Clip thumbnails, generated once per clip version and kept on disk in
/// `AppPaths.thumbsDir` (the OS cache folder: purgeable, never backed up),
/// in two sizes ([ThumbnailTier]).
///
/// - every thumbnail goes through the app's one [ThumbnailQueue], shared with
///   the movie posters; requests for one thumbnail share one generation, and a
///   request can be cancelled until it starts;
/// - the save flows request both tiers of a new clip right away, and
///   [backfill] fills in older clips newest first as the queue's background
///   work;
/// - [load] learns every thumbnail on disk with one listing, and a thumbnail
///   known that way or made this session is served synchronously
///   ([cachedFile]), so a tapped day shows its poster in the same frame;
/// - bounds keep the frame's aspect ratio ([ThumbnailTier.boundsFor]).
///
/// Failures are logged and give null; nothing here throws. Not final so tests
/// can fake it.
class ThumbnailRepository {
  ThumbnailRepository({
    required this._gateway,
    required this._queue,
    required this._metadata,
    required this._paths,
    required this._logger,
  }) {
    _queue.addBackground(_nextBackfillWork);
  }

  final ThumbnailGateway _gateway;
  final ThumbnailQueue _queue;

  /// Where a clip's frame size is known (saved or backfilled), for
  /// aspect-correct bounds ([ThumbnailTier.boundsFor]).
  final ClipMetadataCache _metadata;
  final AppPaths _paths;
  final AppLogger _logger;

  static const String _tag = 'THUMBNAILS';

  /// Thumbnails this session made or found on disk.
  final Set<String> _known = <String>{};

  /// Backfill work, newest clip first; the queue takes it only when no
  /// tile waits. Plain records: the output path and its hash are made only
  /// when one starts, so queueing thousands of clips stays cheap on the UI
  /// isolate.
  final Queue<_Wanted> _background = Queue<_Wanted>();

  /// The last snapshot [backfill] saw, per profile and tier: the next call
  /// queues only what changed since ([ClipIndex.changedSince]), and a
  /// queued clip deleted or rewritten meanwhile is dropped when its turn
  /// comes.
  final Map<(ProfileKey, ThumbnailTier), ClipIndex> _backfilled =
      <(ProfileKey, ThumbnailTier), ClipIndex>{};

  /// Learns every thumbnail earlier sessions left in `thumbsDir`, with ONE
  /// listing in a background isolate (not one `exists()` per tile). Call it
  /// once at startup, before the Diary shows: afterwards [cachedFile]
  /// answers for them from the first frame, and [request] serves them
  /// without taking a generation slot. Never throws: an unreadable folder
  /// is logged and the tiles are checked one by one.
  Future<void> load() async {
    try {
      _known.addAll(await _listThumbnails(_paths.thumbsDir));
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not list the thumbnails; checking them one by one',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The thumbnail of [clip] (seen with [stamp]) at [tier], if this
  /// session has made or found it; null otherwise (use [request]).
  String? cachedFile(
    ClipRef clip, {
    required FileStamp stamp,
    required ThumbnailTier tier,
  }) {
    final String output = _outputFor(clip, stamp, tier);
    return _known.contains(output) ? output : null;
  }

  /// Asks for the thumbnail of [clip] (seen with [stamp]) at [tier]: served
  /// from disk when it exists, generated otherwise. [orientation] is the
  /// profile's canvas, which shapes the frame until the clip's own size is
  /// cached. Cancel the ticket when the tile goes away.
  ThumbnailTicket request(
    ClipRef clip, {
    required FileStamp stamp,
    required ThumbnailTier tier,
    required VideoOrientation orientation,
  }) {
    final String output = _outputFor(clip, stamp, tier);
    if (_known.contains(output)) {
      return ThumbnailTicket(
        file: Future<String?>.value(output),
        onCancel: _ignore,
      );
    }
    // A clip the backfill has queued is made here, on screen now; its
    // backfill turn then finds it made (or being made) and skips it.
    return _queue.request(
      output,
      () => _make(_Wanted(clip, stamp, tier, orientation), output),
    );
  }

  /// [clip] was rewritten in place with the same frames (a subtitle edit,
  /// `ClipSubtitles`): its stamp went from [from] to [to], and each
  /// thumbnail made for [from] serves [to], so no tile shows a placeholder
  /// and nothing is generated again. A thumbnail never made is simply made
  /// for [to] when asked. Never throws: a file that cannot be moved is
  /// logged and generated again.
  Future<void> carryOver(
    ClipRef clip, {
    required FileStamp from,
    required FileStamp to,
  }) async {
    for (final ThumbnailTier tier in ThumbnailTier.values) {
      final String old = _outputFor(clip, from, tier);
      if (!_known.contains(old)) continue;
      final String moved = _outputFor(clip, to, tier);
      try {
        await File(old).rename(moved);
        _known
          ..remove(old)
          ..add(moved);
      } on FileSystemException catch (error, stackTrace) {
        _known.remove(old);
        _logger.warning(
          _tag,
          'Could not keep the ${tier.name} thumbnail of ${clip.relPath}',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Queues the [tier] thumbnail of every clip of [index], newest first,
  /// behind every [request]; thumbnails already made are skipped when
  /// their turn comes, without taking a slot. [orientation] is the
  /// profile's canvas (see [request]).
  ///
  /// Feed it every snapshot of a profile: after the first, only the clips
  /// that changed since the previous one are queued, and a queued clip
  /// that was deleted or rewritten meanwhile is dropped.
  void backfill(
    ClipIndex index, {
    required ThumbnailTier tier,
    required VideoOrientation orientation,
  }) {
    final (ProfileKey, ThumbnailTier) key = (index.profile, tier);
    final ClipIndex? previous = _backfilled[key];
    _backfilled[key] = index;
    final Iterable<ClipRef> clips = previous == null
        ? index.newestFirst
        : index.changedSince(previous);
    for (final ClipRef clip in clips) {
      _background.add(_Wanted(clip, index.stampOf(clip)!, tier, orientation));
    }
    _queue.pump();
  }

  /// The next backfill turn still wanted; null when none is left. Turns
  /// whose thumbnail was made (or is being made) since, and clips deleted
  /// or rewritten since they were queued, are skipped.
  ThumbnailWork? _nextBackfillWork() {
    while (_background.isNotEmpty) {
      final _Wanted next = _background.removeFirst();
      final ClipIndex? latest = _backfilled[(next.clip.profile, next.tier)];
      if (latest?.stampOf(next.clip) != next.stamp) continue;
      final String output = _outputFor(next.clip, next.stamp, next.tier);
      if (_known.contains(output) || _queue.isPending(output)) continue;
      return (key: output, make: () => _make(next, output));
    }
    return null;
  }

  /// [job]'s bounds: from the clip's cached frame size when known, else
  /// from the profile's canvas (`ClipFormat.width` × `height`; the bounds
  /// keep the ratio, so the canvas of any tier on the profile's
  /// orientation gives the same ones).
  ({int width, int height}) _boundsOf(_Wanted job) {
    final ClipMeta? meta = _metadata.lookup(
      relPath: job.clip.relPath,
      stamp: job.stamp,
    );
    final ClipFormat canvas = ClipFormat.legacy(job.orientation);
    return switch ((meta?.width, meta?.height)) {
      (final int width, final int height) when width > 0 && height > 0 =>
        job.tier.boundsFor(width: width, height: height),
      _ => job.tier.boundsFor(width: canvas.width, height: canvas.height),
    };
  }

  /// Serves the thumbnail [job] wants at [output] from disk when an
  /// earlier session made it, else generates it.
  Future<String?> _make(_Wanted job, String output) async {
    if (await File(output).exists()) {
      _known.add(output);
      return output;
    }
    try {
      final ({int width, int height}) bounds = _boundsOf(job);
      final String? written = await _gateway.writeThumbnail(
        videoPath: _paths.absoluteFromVideos(job.clip.relPath),
        outputPath: output,
        maxWidth: bounds.width,
        maxHeight: bounds.height,
        quality: 75,
        timeMs: 0,
      );
      if (written == null) {
        _logFailure(job);
      } else {
        _known.add(written);
      }
      return written;
    } on Exception catch (error, stackTrace) {
      _logFailure(job, error, stackTrace);
      return null;
    }
  }

  static void _ignore() {}

  /// The `.jpg` files in [folder], as paths; none when it does not exist.
  /// Static, so the isolate closure captures only the folder.
  static Future<List<String>> _listThumbnails(String folder) => Isolate.run(() {
    final Directory directory = Directory(folder);
    if (!directory.existsSync()) return const <String>[];
    return <String>[
      for (final FileSystemEntity entity in directory.listSync())
        if (entity is File && entity.path.endsWith('.jpg')) entity.path,
    ];
  }, debugName: 'thumbnails-list');

  /// `<thumbsDir>/<hash(relPath)>_<mtime>_<size>_<width>.jpg`: a clip
  /// rewritten in place (a subtitle edit) gets a new stamp and so a new
  /// file, and two profiles' clips of one day never share one.
  String _outputFor(ClipRef clip, FileStamp stamp, ThumbnailTier tier) =>
      '${_paths.thumbsDir}/${_hash(clip.relPath)}_${stamp.modifiedMs}_'
      '${stamp.sizeBytes}_${tier.maxSide}.jpg';

  void _logFailure(_Wanted job, [Object? error, StackTrace? stackTrace]) =>
      _logger.warning(
        _tag,
        'Could not make the ${job.tier.name} thumbnail of ${job.clip.relPath}',
        error: error,
        stackTrace: stackTrace,
      );

  /// 64-bit FNV-1a of [text], as 16 hex digits.
  static String _hash(String text) {
    int hash = 0xcbf29ce484222325;
    for (final int unit in text.codeUnits) {
      hash = (hash ^ unit) * 0x100000001b3;
    }
    final String high = ((hash >> 32) & 0xffffffff).toRadixString(16);
    final String low = (hash & 0xffffffff).toRadixString(16);
    return '${high.padLeft(8, '0')}${low.padLeft(8, '0')}';
  }
}

/// One thumbnail someone wants: a tile, or a backfill turn.
final class _Wanted {
  const _Wanted(this.clip, this.stamp, this.tier, this.orientation);

  final ClipRef clip;
  final FileStamp stamp;
  final ThumbnailTier tier;

  /// The profile's canvas, for the bounds while the clip's size is unknown.
  final VideoOrientation orientation;
}
