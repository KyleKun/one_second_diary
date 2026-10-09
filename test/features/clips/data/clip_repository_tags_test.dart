// The tags of a clip are in its file, which a listing does not read: the
// repository is told, and every snapshot it publishes carries them.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';

const ProfileKey _default = ProfileKey.defaultProfile;
const ProfileKey _work = ProfileKey('Work');

void main() {
  late AppPaths paths;
  late ClipRepository repository;

  setUp(() async {
    paths = await createTestPaths();
    final MemoryLogSink sink = MemoryLogSink();
    repository = ClipRepository(
      scanner: ClipScanner(paths: paths, logger: memoryLogger(sink)),
      paths: paths,
      logger: memoryLogger(sink),
    );
    addTearDown(repository.dispose);
    await seedClip(paths, _default, LocalDay(2024, 1, 1));
    await seedClip(paths, _default, LocalDay(2024, 1, 2));
    await seedClip(paths, _work, LocalDay(2024, 1, 2));
  });

  List<String> tagsOf(ProfileKey profile, String relPath) => repository
      .snapshotOf(profile)!
      .tagsOf(ClipRef(profile: profile, relPath: relPath));

  test(
    'the tags known at launch are on the first snapshot; a clip tagged '
    'since follows at once, and stays tagged through a rescan and a '
    'rewrite in place; a file no snapshot holds yet is tagged when found',
    () async {
      repository.clipTagsKnown(<String, List<String>>{
        '2024-01-01.mp4': <String>['Trip'],
        'Profiles/Work/2024-01-02.mp4': <String>['bread'],
      });
      await repository.loadAll(active: _default, profiles: <ProfileKey>[_work]);
      expect(tagsOf(_default, '2024-01-01.mp4'), <String>['Trip']);
      expect(tagsOf(_work, 'Profiles/Work/2024-01-02.mp4'), <String>['bread']);
      expect(tagsOf(_default, '2024-01-02.mp4'), isEmpty);

      final List<List<String>> seen = <List<String>>[];
      final StreamSubscription<ClipIndex> watching = repository
          .watch(_default)
          .listen(
            (ClipIndex index) => seen.add(
              index.tagsOf(
                ClipRef(profile: _default, relPath: '2024-01-02.mp4'),
              ),
            ),
          );
      addTearDown(watching.cancel);
      await pumpEventQueue();

      repository.tagsKnown('2024-01-02.mp4', <String>['kids', 'Trip']);
      await pumpEventQueue();
      expect(seen, <List<String>>[
        <String>[],
        <String>['kids', 'Trip'],
      ]);

      // A rescan that finds a new file keeps the tags.
      await seedClip(paths, _default, LocalDay(2024, 1, 3));
      await repository.rescan(_default);
      expect(tagsOf(_default, '2024-01-01.mp4'), <String>['Trip']);
      expect(tagsOf(_default, '2024-01-02.mp4'), <String>['kids', 'Trip']);

      // Rewritten in place (a subtitle or tags edit): still tagged.
      await File(
        paths.absoluteFromVideos('2024-01-01.mp4'),
      ).writeAsBytes(List<int>.filled(999, 2));
      await repository.clipReplaced(
        ClipRef(profile: _default, relPath: '2024-01-01.mp4'),
      );
      expect(tagsOf(_default, '2024-01-01.mp4'), <String>['Trip']);

      // Tags taken away.
      repository.tagsKnown('2024-01-01.mp4', const <String>[]);
      expect(tagsOf(_default, '2024-01-01.mp4'), isEmpty);

      // Known before its file is: the scan that finds it tags it.
      repository.tagsKnown('2024-01-09.mp4', <String>['later']);
      await seedClip(paths, _default, LocalDay(2024, 1, 9));
      await repository.rescan(_default);
      expect(tagsOf(_default, '2024-01-09.mp4'), <String>['later']);
    },
  );

  test(
    "a deleted profile's tags are forgotten, the other profiles' kept",
    () async {
      repository.clipTagsKnown(<String, List<String>>{
        '2024-01-01.mp4': <String>['Trip'],
        'Profiles/Work/2024-01-02.mp4': <String>['bread'],
      });
      await repository.loadAll(active: _default, profiles: <ProfileKey>[_work]);

      repository.profileRemoved(_work);
      // The folder is listed again (a profile of that name made anew).
      await repository.rescan(_work);

      expect(tagsOf(_work, 'Profiles/Work/2024-01-02.mp4'), isEmpty);
      expect(tagsOf(_default, '2024-01-01.mp4'), <String>['Trip']);
    },
  );
}
