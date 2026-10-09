// The library knows which clips were not made by the app from the metadata
// cache (the schema marker is in the file): told at launch and on every
// read, every snapshot carries the flag, and a processed clip loses it.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';

const ProfileKey _default = ProfileKey.defaultProfile;
const FileStamp _stamp = FileStamp(sizeBytes: 8, modifiedMs: 0);

void main() {
  test('foreignClipsKnown before the first scan marks the first snapshot; '
      'schemaKnown patches it; a clip the app adds is its own', () async {
    final AppPaths paths = await createTestPaths();
    final MemoryLogSink sink = MemoryLogSink();
    final ClipRepository repository = ClipRepository(
      scanner: ClipScanner(paths: paths, logger: memoryLogger(sink)),
      paths: paths,
      logger: memoryLogger(sink),
    );
    addTearDown(repository.dispose);
    await seedClip(paths, _default, LocalDay(2024, 1, 5));
    await seedClip(paths, _default, LocalDay(2024, 1, 6));
    repository.foreignClipsKnown(<String>['2024-01-05.mp4']);

    await repository.loadAll(active: _default, profiles: const <ProfileKey>[]);
    ClipIndex index = repository.snapshotOf(_default)!;
    final ClipRef foreign = ClipRef(
      profile: _default,
      relPath: '2024-01-05.mp4',
    );
    expect(index.isForeign(foreign), isTrue);
    expect(index.foreignCount, 1);

    repository.schemaKnown('2024-01-06.mp4', foreign: true);
    expect(repository.snapshotOf(_default)!.foreignCount, 2);

    // Processed: the app published a clip under that name.
    await repository.clipAdded(foreign);
    index = repository.snapshotOf(_default)!;
    expect(index.isForeign(foreign), isFalse);
    expect(index.foreignCount, 1);

    // A rescan keeps the marks.
    await seedClip(paths, _default, LocalDay(2024, 1, 7));
    index = await repository.rescan(_default);
    expect(index.foreignCount, 1);
    expect(
      index.isForeign(ClipRef(profile: _default, relPath: '2024-01-06.mp4')),
      isTrue,
    );
  });

  test('the metadata cache tells which clips are foreign at launch and '
      'each change of schema since, as it does for privacy', () async {
    final AppPaths paths = await createTestPaths();
    final ClipMetadataCache cache = ClipMetadataCache(
      paths: paths,
      logger: memoryLogger(MemoryLogSink()),
    );
    addTearDown(cache.dispose);
    final List<({String relPath, bool isForeign})> told =
        <({String relPath, bool isForeign})>[];
    cache.schemaChanges.listen(told.add);

    cache.put(
      relPath: '2024-01-05.mp4',
      stamp: _stamp,
      meta: const ClipMeta(schema: ClipSchema.other),
    );
    cache.put(
      relPath: '2024-01-06.mp4',
      stamp: _stamp,
      meta: const ClipMeta(schema: ClipSchema.v15),
    );
    expect(cache.foreignRelPaths, <String>{'2024-01-05.mp4'});

    // Processed: written through as the app's own.
    cache.put(
      relPath: '2024-01-05.mp4',
      stamp: _stamp,
      meta: const ClipMeta(schema: ClipSchema.v2, origin: ClipOrigin.import),
    );
    cache.remove('2024-01-06.mp4');
    await Future<void>.delayed(Duration.zero);

    expect(told, <({String relPath, bool isForeign})>[
      (relPath: '2024-01-05.mp4', isForeign: true),
      (relPath: '2024-01-05.mp4', isForeign: false),
    ]);
    expect(cache.foreignRelPaths, isEmpty);
  });
}
