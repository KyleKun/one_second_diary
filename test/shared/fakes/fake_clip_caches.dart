import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_backfill.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/stamped_clip_meta.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_ticket.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/thumbnail_tier.dart';

/// A [ClipMetadataCache] that puts its load in the launch [journal] (the
/// launch order is the outcome `PostFrameLaunch` owes). Tests of what the
/// cache keeps use the real one over a temp folder.
class FakeClipMetadataCache extends Fake implements ClipMetadataCache {
  FakeClipMetadataCache({this.journal});

  final List<String>? journal;

  /// What `lookup` answers, by relPath (at the entry's stamp).
  final Map<String, StampedClipMeta> entries = <String, StampedClipMeta>{};

  @override
  ClipMeta? lookup({required String relPath, required FileStamp stamp}) {
    final StampedClipMeta? entry = entries[relPath];
    return entry != null && entry.stamp == stamp ? entry.meta : null;
  }

  @override
  Future<void> load() async {
    journal?.add('metadata.load');
  }

  @override
  Set<String> get privateRelPaths => const <String>{};

  @override
  Stream<({String relPath, bool isPrivate})> get privacyChanges =>
      const Stream<({String relPath, bool isPrivate})>.empty();

  @override
  Map<String, List<String>> get tagsByRelPath => const <String, List<String>>{};

  @override
  Stream<({String relPath, List<String> tags})> get tagChanges =>
      const Stream<({String relPath, List<String> tags})>.empty();

  @override
  Set<String> get foreignRelPaths => const <String>{};

  @override
  Stream<({String relPath, bool isForeign})> get schemaChanges =>
      const Stream<({String relPath, bool isForeign})>.empty();

  /// The pause flush (`LibraryWiring`): nothing to write.
  @override
  Future<void> flush() async {}
}

/// A [ClipMetadataBackfill] that records the snapshots it was fed, and
/// whether it is paused ([pause] / [resume], as the saves, imports and
/// conversions hold it).
class FakeClipMetadataBackfill extends Fake implements ClipMetadataBackfill {
  final List<ClipIndex> enqueued = <ClipIndex>[];

  /// Outstanding [pause] calls: paused while above zero.
  int pauses = 0;

  @override
  void enqueue(ClipIndex index) => enqueued.add(index);

  @override
  void pause() => pauses++;

  @override
  void resume() => pauses--;

  @override
  Future<void> get whenIdle => Future<void>.value();

  @override
  bool get isRunning => false;
}

/// One [ThumbnailRepository.backfill] call.
typedef ThumbnailBackfill = ({
  ClipIndex index,
  ThumbnailTier tier,
  VideoOrientation orientation,
});

/// One thumbnail: a clip at a stamp, in a tier.
typedef ThumbnailId = ({String relPath, FileStamp stamp, ThumbnailTier tier});

/// A thumbnail asked of a [FakeThumbnailRepository]: complete it
/// with [make] or [fail]; [cancelled] says whether its tile went away.
final class FakeThumbnailRequest {
  FakeThumbnailRequest(this.id, this._repository);

  final ThumbnailId id;
  final FakeThumbnailRepository _repository;
  final Completer<String?> _file = Completer<String?>();
  bool cancelled = false;

  /// The thumbnail is made at [path] (and known from now on).
  void make(String path) {
    _repository.known[id] = path;
    if (!_file.isCompleted) _file.complete(path);
  }

  /// It could not be made.
  void fail() {
    if (!_file.isCompleted) _file.complete(null);
  }
}

/// A [ThumbnailRepository] that records its load and the backfills asked,
/// and serves the thumbnails a test says it [known]s; any other [request]
/// waits in [requests] until the test makes or fails it.
class FakeThumbnailRepository extends Fake implements ThumbnailRepository {
  FakeThumbnailRepository({this.journal});

  final List<String>? journal;
  bool loaded = false;
  final List<ThumbnailBackfill> backfills = <ThumbnailBackfill>[];

  /// The thumbnails made, by clip, stamp and tier.
  final Map<ThumbnailId, String> known = <ThumbnailId, String>{};

  /// Every request not served from [known], in order.
  final List<FakeThumbnailRequest> requests = <FakeThumbnailRequest>[];

  /// The requests still waiting and wanted.
  List<FakeThumbnailRequest> get pending => <FakeThumbnailRequest>[
    for (final FakeThumbnailRequest request in requests)
      if (!request._file.isCompleted && !request.cancelled) request,
  ];

  /// Knows the [tier] thumbnail of [clip] at [stamp] as [path].
  void make(
    ClipRef clip, {
    required FileStamp stamp,
    required ThumbnailTier tier,
    required String path,
  }) => known[(relPath: clip.relPath, stamp: stamp, tier: tier)] = path;

  @override
  String? cachedFile(
    ClipRef clip, {
    required FileStamp stamp,
    required ThumbnailTier tier,
  }) => known[(relPath: clip.relPath, stamp: stamp, tier: tier)];

  @override
  ThumbnailTicket request(
    ClipRef clip, {
    required FileStamp stamp,
    required ThumbnailTier tier,
    required VideoOrientation orientation,
  }) {
    final ThumbnailId id = (relPath: clip.relPath, stamp: stamp, tier: tier);
    final String? made = known[id];
    if (made != null) {
      return ThumbnailTicket(
        file: Future<String?>.value(made),
        onCancel: () {},
      );
    }
    final FakeThumbnailRequest request = FakeThumbnailRequest(id, this);
    requests.add(request);
    return ThumbnailTicket(
      file: request._file.future,
      onCancel: () => request.cancelled = true,
    );
  }

  @override
  Future<void> load() async {
    journal?.add('thumbnails.load');
    loaded = true;
  }

  @override
  void backfill(
    ClipIndex index, {
    required ThumbnailTier tier,
    required VideoOrientation orientation,
  }) => backfills.add((index: index, tier: tier, orientation: orientation));
}
