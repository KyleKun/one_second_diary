// The library learns which clips have a kept original from the Originals folder's
// names: scanned at launch and on resume, followed through every write there;
// a source without a clip is logged and left alone.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/wiring/library_wiring.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/fakes/clip_index_fixture.dart';
import '../../shared/fakes/fake_clip_caches.dart';
import '../../shared/fakes/fake_clip_repository.dart';
import '../../shared/fakes/fake_profiles_repository.dart';
import '../../support/support.dart';
import '../../support/track_1b/eventually.dart';

const ProfileKey _work = ProfileKey('Work');

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late FakeClipRepository clips;
  late OriginalsStore originals;
  late StreamController<AppLifecycleState> lifecycle;
  late LibraryWiring wiring;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    clips = FakeClipRepository();
    originals = OriginalsStore(
      paths: paths,
      gateway: FakeMediaStoreGateway.onDisk(paths),
      logger: memoryLogger(sink),
      isAndroid: true,
    );
    lifecycle = StreamController<AppLifecycleState>.broadcast();
    final ClipMetadataCache metadata = ClipMetadataCache(
      paths: paths,
      logger: memoryLogger(sink),
    );
    wiring = LibraryWiring(
      profiles: FakeProfilesRepository(
        profiles: <Profile>[
          testProfile(),
          testProfile(key: _work),
        ],
        active: _work,
      ),
      clips: clips,
      backfill: FakeClipMetadataBackfill(),
      thumbnails: FakeThumbnailRepository(),
      metadata: metadata,
      midnight: MidnightTicker(clock: FakeClock(DateTime(2024, 1, 5, 10))),
      lifecycleStates: lifecycle.stream,
      logger: memoryLogger(sink),
      originals: originals,
    );
    addTearDown(() async {
      await wiring.dispose();
      await originals.dispose();
      await clips.close();
      await lifecycle.close();
    });
  });

  Future<void> keep(String originalRelPath) async {
    final File file = File(originals.absoluteOf(originalRelPath));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(fakeVideoBytes);
  }

  test('at start the folder\'s names mark the snapshots\' clips as having '
      'a source; a source whose clip is gone is logged and left alone; a '
      'write in the folder and a resume follow', () async {
    await keep('Profiles/Work/2024-01-05.mov');
    await keep('Profiles/Work/2024-01-09.mp4');
    await keep('2024-01-06.mov');
    clips
      ..publish(clipIndexOf(_work, <LocalDay>[LocalDay(2024, 1, 5)]))
      ..publish(
        clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[
          LocalDay(2024, 1, 6),
        ]),
      );

    wiring.start();
    await eventually(() => clips.sources.isNotEmpty);

    expect(clips.sources.single, <String>{
      'Profiles/Work/2024-01-05.mp4',
      'Profiles/Work/2024-01-09.mp4',
      '2024-01-06.mp4',
    });
    expect(
      clips
          .snapshotOf(_work)!
          .hasSource(
            ClipRef(profile: _work, relPath: 'Profiles/Work/2024-01-05.mp4'),
          ),
      isTrue,
    );
    expect(
      sink.lines.where((String line) => line.contains('has no clip')).single,
      contains('Profiles/Work/2024-01-09.mp4'),
    );
    expect(
      File(originals.absoluteOf('Profiles/Work/2024-01-09.mp4')).existsSync(),
      isTrue,
      reason: 'left alone: the user may be mid-restore',
    );

    // A write in the folder: the library follows at once.
    await originals.remove('2024-01-06.mov');
    await pumpEventQueue();
    expect(clips.sources.last, <String>{
      'Profiles/Work/2024-01-05.mp4',
      'Profiles/Work/2024-01-09.mp4',
    });

    // Deleted in a file manager while away: a resume scans again.
    File(originals.absoluteOf('Profiles/Work/2024-01-05.mov')).deleteSync();
    lifecycle.add(AppLifecycleState.resumed);
    await eventually(
      () => setEquals(clips.sources.last, <String>{
        'Profiles/Work/2024-01-09.mp4',
      }),
    );
  });
}
