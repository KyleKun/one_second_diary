// The tags the metadata cache knows are in the library from its first
// snapshot, and each clip read or tagged since follows.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/wiring/library_wiring.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/fakes/clip_index_fixture.dart';
import '../../shared/fakes/fake_clip_caches.dart';
import '../../shared/fakes/fake_clip_repository.dart';
import '../../shared/fakes/fake_profiles_repository.dart';
import '../../support/support.dart';

const ProfileKey _default = ProfileKey.defaultProfile;
const FileStamp _stamp = FileStamp(sizeBytes: 8, modifiedMs: 0);

void main() {
  late FakeClipRepository clips;
  late ClipMetadataCache metadata;
  late StreamController<AppLifecycleState> lifecycle;

  setUp(() async {
    final AppPaths paths = await createTestPaths();
    final FakeClock clock = FakeClock(DateTime(2024, 1, 5, 10));
    final AppLogger logger = memoryLogger(MemoryLogSink(), clock: clock);
    clips = FakeClipRepository();
    metadata = ClipMetadataCache(paths: paths, logger: logger);
    lifecycle = StreamController<AppLifecycleState>.broadcast();
    final LibraryWiring wiring = LibraryWiring(
      profiles: FakeProfilesRepository(),
      clips: clips,
      backfill: FakeClipMetadataBackfill(),
      thumbnails: FakeThumbnailRepository(),
      metadata: metadata,
      midnight: MidnightTicker(clock: clock),
      lifecycleStates: lifecycle.stream,
      logger: logger,
    );
    addTearDown(() async {
      await wiring.dispose();
      await metadata.dispose();
      await clips.close();
      await lifecycle.close();
    });
    metadata.put(
      relPath: '2024-01-01.mp4',
      stamp: _stamp,
      meta: const ClipMeta(tags: <String>['Trip', 'bread']),
    );
    metadata.put(
      relPath: '2024-01-02.mp4',
      stamp: _stamp,
      meta: const ClipMeta(tags: <String>[]),
    );
    wiring.start();
  });

  test(
    'the tags the cache holds are known before the clips are scanned; a '
    'clip read or tagged later follows, as does one the app deleted',
    () async {
      expect(clips.tags, <String, List<String>>{
        '2024-01-01.mp4': <String>['Trip', 'bread'],
      });

      // The first snapshot comes tagged.
      clips.publish(
        clipIndexOf(_default, <LocalDay>[
          LocalDay(2024, 1, 1),
          LocalDay(2024, 1, 2),
          LocalDay(2024, 1, 3),
        ]),
      );
      List<String> tagsOf(String relPath) => clips
          .snapshotOf(_default)!
          .tagsOf(ClipRef(profile: _default, relPath: relPath));
      expect(tagsOf('2024-01-01.mp4'), <String>['bread', 'Trip']);
      expect(tagsOf('2024-01-03.mp4'), isEmpty);

      // The backfill reads a clip whose file carries tags.
      metadata.put(
        relPath: '2024-01-03.mp4',
        stamp: _stamp,
        meta: const ClipMeta(tags: <String>['kids']),
      );
      await pumpEventQueue();
      expect(tagsOf('2024-01-03.mp4'), <String>['kids']);

      // Read again without tags (its file was rewritten without them).
      metadata.put(
        relPath: '2024-01-01.mp4',
        stamp: const FileStamp(sizeBytes: 9, modifiedMs: 1),
        meta: const ClipMeta(tags: <String>[]),
      );
      await pumpEventQueue();
      expect(tagsOf('2024-01-01.mp4'), isEmpty);

      // Deleted by the app: forgotten.
      metadata.remove('2024-01-03.mp4');
      await pumpEventQueue();
      expect(clips.tags, isEmpty);
      expect(tagsOf('2024-01-03.mp4'), isEmpty);
    },
  );
}
