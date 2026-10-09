// Settings › Tags rewrites clips one at a time: a rename (a merge when the
// name exists) or a removal reaches every clip carrying the tag across the
// loaded profiles, reports its progress, counts a clip that fails and goes
// on, and stops where the user asked.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/data/clip_tags.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/tag_batch.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_queue.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/tag_batch_event.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/scripted_media_store_gateway.dart';

const ProfileKey _work = ProfileKey('Work');
const ProfileKey _default = ProfileKey.defaultProfile;

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late ScriptedMediaStoreGateway gallery;
  late FakeMediaEngine engine;
  late ClipRepository repository;
  late PrefsStore prefs;
  late TagColors colors;
  late TagBatch batch;

  /// Work: two tagged clips and one without the tag; Default: one tagged.
  late ClipRef work5;
  late ClipRef work6;
  late ClipRef work7;
  late ClipRef default8;

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
    final ClipMetadataCache metadata = ClipMetadataCache(
      paths: paths,
      logger: memoryLogger(sink),
    );
    addTearDown(metadata.dispose);
    final ClipTags tags = ClipTags(
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
    prefs = await openLegacyPrefs(<String, Object>{});
    colors = TagColors(prefs: prefs, logger: memoryLogger(sink));
    addTearDown(colors.dispose);
    batch = TagBatch(
      tags: tags,
      clips: repository,
      colors: colors,
      logger: memoryLogger(sink),
    );

    Future<ClipRef> seed(ProfileKey profile, int day) async => ClipRef(
      profile: profile,
      relPath: paths.relativeToVideos(
        (await seedClip(paths, profile, LocalDay(2024, 1, day))).path,
      ),
    );
    work5 = await seed(_work, 5);
    work6 = await seed(_work, 6);
    work7 = await seed(_work, 7);
    default8 = await seed(_default, 8);
    await repository.loadAll(active: _work, profiles: <ProfileKey>[_default]);
    repository
      ..tagsKnown(work5.relPath, <String>['bread', 'Trip'])
      ..tagsKnown(work6.relPath, <String>['trip'])
      ..tagsKnown(work7.relPath, <String>['kids'])
      ..tagsKnown(default8.relPath, <String>['TRIP', 'kids']);
  });

  List<String> tagsOf(ClipRef clip) =>
      repository.snapshotOf(clip.profile)!.tagsOf(clip);

  test('a rename reaches every clip carrying the tag, in both profiles, '
      'reporting each clip then the outcome; the clips without it are left '
      'alone and the colour chosen for the tag moves with it', () async {
    await colors.set('trip', 9);
    final CancelToken token = CancelToken();

    final List<TagBatchEvent> events = await batch
        .rename('trip', 'journey', cancelToken: token)
        .toList();

    expect(events, const <TagBatchEvent>[
      TagBatchProgress(done: 0, total: 3),
      TagBatchProgress(done: 1, total: 3),
      TagBatchProgress(done: 2, total: 3),
      TagBatchProgress(done: 3, total: 3),
      TagBatchFinished(updated: 3, failed: 0, stopped: false),
    ]);
    expect(tagsOf(work5), <String>['bread', 'journey']);
    expect(tagsOf(work6), <String>['journey']);
    expect(tagsOf(work7), <String>['kids']);
    expect(tagsOf(default8), <String>['journey', 'kids']);
    expect(engine.tagRequests, hasLength(3));
    expect(colors.isChosen('trip'), isFalse);
    expect(colors.indexOf('Journey'), 9);
    expect(prefs.read(PrefKeys.tagColors), '{"journey":9}');
  });

  test('a rename onto a tag the clips already carry merges: each clip ends '
      'up with the target once, spelt as the target is', () async {
    final List<TagBatchEvent> events = await batch
        .rename('trip', 'Kids', cancelToken: CancelToken())
        .toList();

    expect(
      events.last,
      const TagBatchFinished(updated: 3, failed: 0, stopped: false),
    );
    expect(tagsOf(work5), <String>['bread', 'Kids']);
    expect(tagsOf(work6), <String>['Kids']);
    expect(tagsOf(work7), <String>['kids']);
    expect(tagsOf(default8), <String>['kids']);
  });

  test('a removal takes the tag off every clip and forgets its colour; a '
      'tag no clip carries is a batch of none', () async {
    await colors.set('trip', 9);

    final List<TagBatchEvent> events = await batch
        .remove('TRIP', cancelToken: CancelToken())
        .toList();

    expect(
      events.last,
      const TagBatchFinished(updated: 3, failed: 0, stopped: false),
    );
    expect(tagsOf(work5), <String>['bread']);
    expect(tagsOf(work6), isEmpty);
    expect(tagsOf(default8), <String>['kids']);
    expect(colors.isChosen('trip'), isFalse);

    expect(
      await batch.remove('nothing', cancelToken: CancelToken()).toList(),
      const <TagBatchEvent>[
        TagBatchProgress(done: 0, total: 0),
        TagBatchFinished(updated: 0, failed: 0, stopped: false),
      ],
    );
  });

  test('a clip the phone refuses to rewrite is counted as failed, logged, '
      'and left as it was; the run goes on with the others', () async {
    gallery.publishResults.add(false);

    final List<TagBatchEvent> events = await batch
        .rename('trip', 'journey', cancelToken: CancelToken())
        .toList();

    expect(
      events.last,
      const TagBatchFinished(updated: 2, failed: 1, stopped: false),
    );
    expect(events, hasLength(5), reason: 'the failed clip still counts');
    // The newest clip of Work goes first and was the one refused.
    expect(tagsOf(work6), <String>['trip']);
    expect(tagsOf(work5), <String>['bread', 'journey']);
    expect(tagsOf(default8), <String>['journey', 'kids']);
    expect(
      sink.lines.where((String line) => line.contains('[TAGS]')),
      isNotEmpty,
    );
  });

  test('cancelling after the first clip stops the run there: that clip keeps '
      'its change, the others are as they were', () async {
    final CancelToken token = CancelToken();
    final List<TagBatchEvent> events = <TagBatchEvent>[];

    await for (final TagBatchEvent event in batch.rename(
      'trip',
      'journey',
      cancelToken: token,
    )) {
      events.add(event);
      if (event case TagBatchProgress(done: 1)) token.cancel();
    }

    expect(events, const <TagBatchEvent>[
      TagBatchProgress(done: 0, total: 3),
      TagBatchProgress(done: 1, total: 3),
      TagBatchFinished(updated: 1, failed: 0, stopped: true),
    ]);
    expect(tagsOf(work6), <String>['journey']);
    expect(tagsOf(work5), <String>['bread', 'Trip']);
    expect(tagsOf(default8), <String>['TRIP', 'kids']);
    expect(engine.tagRequests, hasLength(1));
  });
}
