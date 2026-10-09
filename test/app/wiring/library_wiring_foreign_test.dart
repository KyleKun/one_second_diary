// Clips the metadata cache knows were not made by the app (`ClipSchema.other`)
// are foreign in the library from its first snapshot, and each clip read since follows.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/wiring/library_wiring.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
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
      meta: const ClipMeta(schema: ClipSchema.other),
    );
    metadata.put(
      relPath: '2024-01-02.mp4',
      stamp: _stamp,
      meta: const ClipMeta(schema: ClipSchema.v15),
    );
    wiring.start();
  });

  test('the foreign clips the cache holds are known before the clips are '
      'scanned; a clip read later follows, and a processed one (now the '
      "app's) stops being foreign", () async {
    expect(clips.foreign, <String>{'2024-01-01.mp4'});

    // The first snapshot comes marked.
    clips.publish(
      clipIndexOf(_default, <LocalDay>[
        LocalDay(2024, 1, 1),
        LocalDay(2024, 1, 2),
        LocalDay(2024, 1, 3),
      ]),
    );
    bool isForeign(String relPath) => clips
        .snapshotOf(_default)!
        .isForeign(ClipRef(profile: _default, relPath: relPath));
    expect(isForeign('2024-01-01.mp4'), isTrue);
    expect(isForeign('2024-01-02.mp4'), isFalse);
    expect(isForeign('2024-01-03.mp4'), isFalse);

    // The backfill reads a clip whose file carries no marker of the app's.
    metadata.put(
      relPath: '2024-01-03.mp4',
      stamp: _stamp,
      meta: const ClipMeta(schema: ClipSchema.other),
    );
    await pumpEventQueue();
    expect(isForeign('2024-01-03.mp4'), isTrue);

    // Processed: the file was rewritten with the app's marker.
    metadata.put(
      relPath: '2024-01-01.mp4',
      stamp: const FileStamp(sizeBytes: 9, modifiedMs: 1),
      meta: const ClipMeta(schema: ClipSchema.v2),
    );
    await pumpEventQueue();
    expect(isForeign('2024-01-01.mp4'), isFalse);
    expect(clips.foreign, <String>{'2024-01-03.mp4'});
  });
}
