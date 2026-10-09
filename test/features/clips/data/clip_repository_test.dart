import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/gated_clip_scanner.dart';
import '../../../support/track_1b/locked_folder.dart';

const ProfileKey _default = ProfileKey.defaultProfile;
const ProfileKey _work = ProfileKey('Work');
const ProfileKey _kids = ProfileKey('Kids');

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late ClipRepository repository;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    repository = ClipRepository(
      scanner: ClipScanner(paths: paths, logger: memoryLogger(sink)),
      paths: paths,
      logger: memoryLogger(sink),
    );
    addTearDown(repository.dispose);
  });

  test('loads a snapshot of every profile, the active one published before '
      'the others are scanned; watch emits the current snapshot first, then '
      'every new one; a rescan that finds nothing new emits nothing', () async {
    await seedClip(paths, _default, LocalDay(2024, 1, 1));
    await seedClip(paths, _work, LocalDay(2024, 1, 2));
    await seedClip(paths, _work, LocalDay(2024, 1, 3));
    final List<ProfileKey> published = <ProfileKey>[];
    for (final ProfileKey profile in <ProfileKey>[_default, _work, _kids]) {
      final StreamSubscription<ClipIndex> subscription = repository
          .watch(profile)
          .listen((ClipIndex index) => published.add(index.profile));
      addTearDown(subscription.cancel);
    }

    await repository.loadAll(
      active: _kids,
      profiles: <ProfileKey>[_default, _work, _kids],
    );
    await pumpEventQueue();

    expect(published, <ProfileKey>[_kids, _default, _work]);
    final Map<ProfileKey, ClipIndex> snapshots = repository.snapshots;
    expect(snapshots.keys, <ProfileKey>[_kids, _default, _work]);
    expect(snapshots[_default]!.clipCount, 1);
    expect(snapshots[_work]!.clipCount, 2);
    expect(snapshots[_kids]!.isEmpty, isTrue);

    // Watching.
    {
      await seedClip(paths, _default, LocalDay(2024, 1, 1));
      await repository.loadAll(active: _default, profiles: <ProfileKey>[]);
      final List<int> counts = <int>[];
      final StreamSubscription<ClipIndex> subscription = repository
          .watch(_default)
          .listen((ClipIndex index) => counts.add(index.clipCount));
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await seedClip(paths, _default, LocalDay(2024, 1, 2));
      final ClipIndex rescanned = await repository.rescan(_default);
      await pumpEventQueue();

      expect(counts, <int>[1, 2]);
      expect(rescanned.clipCount, 2);
      expect(repository.snapshotOf(_default), same(rescanned));

      // A rescan that finds nothing new keeps the snapshot and emits nothing.
      final ClipIndex again = await repository.rescan(_default);
      await pumpEventQueue();
      expect(again, same(rescanned));
      expect(counts, <int>[1, 2]);
    }
  });

  group('on resume, only profiles whose folders changed are rescanned', () {
    test(
      'an untouched profile keeps its snapshot and a changed one '
      'is rescanned and diffed; a removed profile leaves the snapshots and '
      'its watchers get an empty index, even while its scan is in flight',
      () async {
        final File rewritten = await seedClip(
          paths,
          _work,
          LocalDay(2024, 1, 2),
        );
        await seedClip(paths, _default, LocalDay(2024, 1, 1));
        await repository.loadAll(
          active: _default,
          profiles: <ProfileKey>[_work],
        );
        final ClipIndex work = repository.snapshotOf(_work)!;
        // Rewritten in place: no folder entry changes, so no rescan (a
        // rescan would pick up the new size).
        await rewritten.writeAsBytes(List<int>.filled(500, 3));
        // Added by the Gallery or the Files app.
        await seedClip(
          paths,
          _default,
          LocalDay(2024, 1, 5),
          subFolder: 'trip',
        );

        await repository.rescanChanged(active: _work);

        expect(repository.snapshotOf(_work), same(work));
        expect(
          repository.snapshotOf(_default)!.hasDay(LocalDay(2024, 1, 5)),
          isTrue,
        );

        // A removed profile.
        {
          final GatedClipScanner scanner = GatedClipScanner(
            paths: paths,
            logger: memoryLogger(sink),
          );
          repository = ClipRepository(
            scanner: scanner,
            paths: paths,
            logger: memoryLogger(sink),
          );
          addTearDown(repository.dispose);
          await seedClip(paths, _work, LocalDay(2024, 1, 2));
          scanner.hold = true;
          final Future<void> loading = repository.loadAll(
            active: _work,
            profiles: <ProfileKey>[],
          );
          while (scanner.heldScans < 1) {
            await pumpEventQueue(times: 1);
          }
          final List<int> seen = <int>[];
          final StreamSubscription<ClipIndex> subscription = repository
              .watch(_work)
              .listen((ClipIndex index) => seen.add(index.clipCount));
          addTearDown(subscription.cancel);

          repository.profileRemoved(_work);
          scanner.releaseNext();
          await loading;
          await pumpEventQueue();

          expect(seen, <int>[0]);

          expect(repository.snapshotOf(_work), isNull);
          expect(repository.snapshots, isEmpty);
        }
      },
    );
  });

  group('a profile that cannot be read', () {
    late String workFolder;

    setUp(() async {
      await seedClip(paths, _default, LocalDay(2024, 1, 1));
      await seedClip(paths, _work, LocalDay(2024, 1, 2));
      workFolder = paths.profileVideos(_work);
    });

    Future<bool> lock() => lockFolder(workFolder);
    Future<void> unlock() => Process.run('chmod', <String>['755', workFolder]);

    test('is logged and reported to its watchers while the others still load, '
        'keeps its last snapshot when a rescan fails, and is retried on the '
        'next resume', () async {
      if (!await lock()) return;
      final List<Object> errors = <Object>[];
      final StreamSubscription<ClipIndex> subscription = repository
          .watch(_work)
          .listen(null, onError: (Object error) => errors.add(error));
      addTearDown(subscription.cancel);

      await repository.loadAll(active: _work, profiles: <ProfileKey>[_default]);
      await pumpEventQueue();

      expect(errors.single, isA<StorageException>());
      expect(repository.snapshots.keys, <ProfileKey>[_default]);
      expect(
        sink.lines,
        contains(
          allOf(
            startsWith('[ERROR] '),
            contains('[CALENDAR] Could not scan profile Work'),
          ),
        ),
      );

      await unlock();
      await repository.rescanChanged(active: _work);
      expect(repository.snapshotOf(_work)!.clipCount, 1);

      // A rescan that fails keeps the last snapshot, and the caller hears of it.
      {
        await repository.loadAll(active: _work, profiles: <ProfileKey>[]);
        final ClipIndex before = repository.snapshotOf(_work)!;
        if (!await lock()) return;

        await expectLater(
          repository.rescan(_work),
          throwsA(isA<StorageException>()),
        );
        expect(repository.snapshotOf(_work), same(before));
      }
    });
  });

  group('a scan racing other changes', () {
    late GatedClipScanner scanner;

    setUp(() async {
      scanner = GatedClipScanner(paths: paths, logger: memoryLogger(sink));
      repository = ClipRepository(
        scanner: scanner,
        paths: paths,
        logger: memoryLogger(sink),
      );
      addTearDown(repository.dispose);
      await seedClip(paths, _default, LocalDay(2024, 1, 1));
      await repository.loadAll(active: _default, profiles: <ProfileKey>[]);
    });

    Future<void> untilHeld(int scans) async {
      while (scanner.heldScans < scans) {
        await pumpEventQueue(times: 1);
      }
    }

    test('a clip saved while a scan is in flight survives the older '
        'listing', () async {
      scanner.hold = true;
      final Future<ClipIndex> rescan = repository.rescan(_default);
      await untilHeld(1);
      await seedClip(paths, _default, LocalDay(2024, 1, 2));
      await repository.clipAdded(
        ClipRef(profile: _default, relPath: '2024-01-02.mp4'),
      );

      scanner.releaseNext();
      await rescan;

      expect(
        repository.snapshotOf(_default)!.hasDay(LocalDay(2024, 1, 2)),
        isTrue,
      );
    });
  });

  group("write-through patches for the app's own writes", () {
    ClipRef ref(ProfileKey profile, String relPath) =>
        ClipRef(profile: profile, relPath: relPath);

    setUp(() async {
      await seedClip(paths, _default, LocalDay(2024, 1, 1));
      await seedClip(paths, _default, LocalDay(2024, 1, 1), subFolder: 'Old');
      await seedClip(paths, _work, LocalDay(2024, 1, 2));
      await repository.loadAll(active: _default, profiles: <ProfileKey>[_work]);
    });

    test(
      'an added clip appears with its stamp from disk and watchers see it; '
      'a write whose file is not on disk is not indexed; a replaced clip '
      'keeps its place; a removed one brings back the duplicate it hid',
      () async {
        final List<int> counts = <int>[];
        final StreamSubscription<ClipIndex> subscription = repository
            .watch(_work)
            .listen((ClipIndex index) => counts.add(index.clipCount));
        addTearDown(subscription.cancel);
        final File file = await seedClip(
          paths,
          _work,
          LocalDay(2024, 1, 2),
          ordinal: 2,
          bytes: List<int>.filled(300, 1),
        );

        await repository.clipAdded(
          ref(_work, 'Profiles/Work/2024-01-02-2.mp4'),
        );
        await pumpEventQueue();

        final ClipIndex index = repository.snapshotOf(_work)!;
        final ClipRef added = index.clipsOn(LocalDay(2024, 1, 2)).last;
        expect(added.relPath, 'Profiles/Work/2024-01-02-2.mp4');
        expect(
          index.stampOf(added),
          FileStamp(
            sizeBytes: 300,
            modifiedMs: (await file.lastModified()).millisecondsSinceEpoch,
          ),
        );
        expect(counts, <int>[1, 2]);

        // A reported write whose file is not on disk is logged, not indexed.
        await repository.clipAdded(ref(_work, 'Profiles/Work/2024-01-09.mp4'));

        expect(
          repository.snapshotOf(_work)!.hasDay(LocalDay(2024, 1, 9)),
          isFalse,
        );
        expect(
          sink.lines,
          contains(
            allOf(
              startsWith('[WARNING] '),
              contains(
                '[CALENDAR] Ignored a write to a file that does not exist: '
                'Profiles/Work/2024-01-09.mp4',
              ),
            ),
          ),
        );

        // Replaced and removed.
        {
          final ClipRef clip = ref(_default, '2024-01-01.mp4');
          final FileStamp before = repository
              .snapshotOf(_default)!
              .stampOf(clip)!;
          await File(
            paths.absoluteFromVideos(clip.relPath),
          ).writeAsBytes(List<int>.filled(999, 2));

          await repository.clipReplaced(clip);

          final FileStamp after = repository
              .snapshotOf(_default)!
              .stampOf(clip)!;
          expect(after.sizeBytes, 999);
          expect(after, isNot(before));

          // A removed clip disappears and the duplicate it hid comes back.
          await File(paths.absoluteFromVideos('2024-01-01.mp4')).delete();
          repository.clipRemoved(ref(_default, '2024-01-01.mp4'));
          expect(
            repository
                .snapshotOf(_default)!
                .clipsOn(LocalDay(2024, 1, 1))
                .single
                .relPath,
            'Old/2024-01-01.mp4',
          );
        }
      },
    );
  });
}
