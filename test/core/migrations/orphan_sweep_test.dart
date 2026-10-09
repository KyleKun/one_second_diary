import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/migrations/orphan_sweep.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../support/support.dart';
import '../../support/track_1c/read_only_folder.dart';

void main() {
  late AppPaths paths;
  late MemoryLogSink log;
  late FakeClock clock;

  setUp(() async {
    paths = await createTestPaths();
    log = MemoryLogSink();
    clock = FakeClock(DateTime.now());
  });

  Future<File> writeFile(String path) async {
    final File file = File(path);
    await file.parent.create(recursive: true);
    return file.writeAsBytes(fakeVideoBytes);
  }

  OrphanSweep sweep() =>
      OrphanSweep(paths: paths, clock: clock, logger: memoryLogger(log));

  test('deletes the movie temps v1.x left next to their clip in a profile\'s '
      'own folder, and nothing else', () async {
    final File rootTemp = await seedFile(paths, '2024-01-05_123456.mp4');
    final File profileTemp = await seedFile(
      paths,
      'Profiles/Work/2024-01-05_7.mp4',
    );
    final List<File> kept = <File>[
      await seedClip(paths, ProfileKey.defaultProfile, LocalDay(2024, 1, 5)),
      await seedClip(
        paths,
        ProfileKey.defaultProfile,
        LocalDay(2024, 1, 5),
        ordinal: 2,
      ),
      await seedClip(paths, const ProfileKey('Work'), LocalDay(2024, 1, 5)),
      await seedFile(paths, 'Movies/2024-01-05_123456.mp4'),
      await seedFile(paths, '2024-01-05_1234567.mp4'),
      await seedFile(paths, 'notes.txt'),
    ];

    await sweep().run(isMediaBusy: () => false);

    expect(await rootTemp.exists(), isFalse);
    expect(await profileTemp.exists(), isFalse);
    for (final File file in kept) {
      expect(await file.exists(), isTrue, reason: file.path);
    }
  });

  test('never touches a user-made sub-folder: v1.x wrote its temps only '
      'directly in a profile\'s own folder (create_movie_button.dart:114-135 '
      'from v1.5 to v1.7.1), so a look-alike there is the user\'s', () async {
    final List<File> kept = <File>[
      await seedClip(
        paths,
        ProfileKey.defaultProfile,
        LocalDay(2024, 1, 6),
        subFolder: 'trip',
      ),
      await seedFile(paths, 'trip/2024-01-06_42.mp4'),
      await seedFile(paths, 'Backup/2024-01-06_2.mp4'),
      await seedClip(
        paths,
        const ProfileKey('Work'),
        LocalDay(2024, 1, 6),
        subFolder: 'rio',
      ),
      await seedFile(paths, 'Profiles/Work/rio/2024-01-06_7.mp4'),
    ];

    await sweep().run(isMediaBusy: () => false);

    for (final File file in kept) {
      expect(await file.exists(), isTrue, reason: file.path);
    }
  });

  test('a look-alike without its clip beside it is the user\'s file and '
      'stays: v1.x named every temp after the clip it copied, in the same '
      'folder', () async {
    await seedClip(
      paths,
      ProfileKey.defaultProfile,
      LocalDay(2024, 2, 1),
      subFolder: 'trip',
    );
    final List<File> kept = <File>[
      await seedFile(paths, '2024-02-01_2.mp4'),
      await seedFile(paths, 'Profiles/Work/2024-02-01_3.mp4'),
    ];

    await sweep().run(isMediaBusy: () => false);

    for (final File file in kept) {
      expect(await file.exists(), isTrue, reason: file.path);
    }
  });

  test('while a media job runs it touches nothing: the job may own any temp '
      'or scratch file (SYNTHESIS Appendix C)', () async {
    await seedClip(paths, ProfileKey.defaultProfile, LocalDay(2024, 1, 5));
    final File temp = await seedFile(paths, '2024-01-05_123456.mp4');
    final File scratch = await writeFile('${paths.scratchDir}/job-1/out.mp4');

    await sweep().run(isMediaBusy: () => true);

    expect(await temp.exists(), isTrue);
    expect(await scratch.exists(), isTrue);
  });

  test('empties the scratch folder, whose per-job folders never outlive the '
      'process that made them', () async {
    await writeFile('${paths.scratchDir}/job-1/out.mp4');
    await writeFile('${paths.scratchDir}/legacy_migration/2021-01-01.mp4');
    final File outside = await writeFile('${paths.cacheDir}/picked.mp4');

    await sweep().run(isMediaBusy: () => false);

    expect(await Directory(paths.scratchDir).list().toList(), isEmpty);
    expect(await outside.exists(), isTrue, reason: 'temp == cache: not ours');
  });

  test('deletes trash entries older than a week and keeps younger ones, in '
      'case a replace a kill interrupted still needs its backup', () async {
    final File young = await writeFile('${paths.trashDir}/entry-1/clip.mp4');

    await sweep().run(isMediaBusy: () => false);
    expect(await young.exists(), isTrue);

    clock.advance(OrphanSweep.trashRetention + const Duration(hours: 1));
    await sweep().run(isMediaBusy: () => false);

    expect(await Directory(paths.trashDir).list().toList(), isEmpty);
  });

  // A pending entry can hold the only copy of a clip: Android's media store deletes the
  // old row before its insert, so a replace killed in between leaves only the backup.
  // MediaPublisher.purgeTrash() puts it back at launch, and keeps it while it cannot; age
  // never makes it deletable.
  test('never deletes a pending trash entry, however old', () async {
    final File pending = await writeFile(
      '${paths.trashDir}/1700000000-0.pending/Profiles/Work/2024-01-05.mp4',
    );
    clock.advance(OrphanSweep.trashRetention * 10);

    await sweep().run(isMediaBusy: () => false);

    expect(await pending.exists(), isTrue);
  });

  test('a temp it may not unlink (a previous install made it) stays and is '
      'logged, and the sweep goes on: it never asks the media store, which '
      'would prompt for consent at every launch', () async {
    await seedClip(paths, ProfileKey.defaultProfile, LocalDay(2024, 1, 5));
    final File deleted = await seedFile(paths, '2024-01-05_123456.mp4');
    await seedClip(paths, const ProfileKey('Work'), LocalDay(2024, 1, 5));
    final File refused = await seedFile(
      paths,
      'Profiles/Work/2024-01-05_7.mp4',
    );
    await writeFile('${paths.scratchDir}/job-1/out.mp4');
    if (!makeReadOnly(refused.parent.path)) {
      markTestSkipped('This user can unlink in a mode-555 folder (root?).');
      return;
    }

    await sweep().run(isMediaBusy: () => false);

    expect(await deleted.exists(), isFalse);
    expect(await refused.exists(), isTrue);
    expect(await Directory(paths.scratchDir).list().toList(), isEmpty);
    expect(
      log.lines,
      contains(allOf(startsWith('[WARNING]'), contains(refused.path))),
    );
  });
}
