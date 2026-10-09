import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_scan.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/domain/movie_selection.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/locked_folder.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

List<String> _visible(ClipIndex index) => <String>[
  for (final ClipRef clip in index.newestFirst.toList().reversed) clip.relPath,
];

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late ClipScanner scanner;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    scanner = ClipScanner(paths: paths, logger: memoryLogger(sink));
  });

  test(
    'Default: the videos root recursively, without the top-level '
    'Profiles/ and Movies/ folders by path segment (decision O1, E-2)',
    () async {
      await seedClip(paths, _default, LocalDay(2024, 1, 1));
      await seedClip(
        paths,
        _default,
        LocalDay(2024, 1, 2),
        subFolder: 'Backup',
      );
      await seedClip(paths, _default, LocalDay(2024, 1, 3), subFolder: 'a/b');
      await seedClip(
        paths,
        _default,
        LocalDay(2024, 1, 4),
        subFolder: 'trip/Movies',
      );
      await seedClip(paths, const ProfileKey('Travel'), LocalDay(2024, 2, 1));
      await seedFile(paths, 'Movies/2024-01-05.mp4');
      await seedFile(paths, 'Movies/OSD-Movie-1-2024-01-05.mp4');
      // Top-level folders whose names only contain "Movies" or "Profiles"
      // keep their clips (folders match by path segment).
      for (final (String folder, int day) in <(String, int)>[
        ('My Movies', 6),
        ('Profiles backup', 7),
        ('Movies2', 8),
      ]) {
        await seedClip(
          paths,
          _default,
          LocalDay(2024, 1, day),
          subFolder: folder,
        );
      }

      final ClipScan scan = await scanner.scan(_default);

      expect(_visible(scan.index), <String>[
        '2024-01-01.mp4',
        'Backup/2024-01-02.mp4',
        'a/b/2024-01-03.mp4',
        'trip/Movies/2024-01-04.mp4',
        'My Movies/2024-01-06.mp4',
        'Profiles backup/2024-01-07.mp4',
        'Movies2/2024-01-08.mp4',
      ]);
    },
  );

  test('a named profile: Profiles/<key>/ recursively, nothing else; each '
      'clip records its size and modification time', () async {
    const ProfileKey work = ProfileKey('Work');
    await seedClip(paths, work, LocalDay(2024, 1, 1));
    await seedClip(paths, work, LocalDay(2024, 1, 2), subFolder: 'old');
    await seedClip(paths, _default, LocalDay(2024, 1, 3));
    await seedClip(paths, const ProfileKey('Workshop'), LocalDay(2024, 1, 4));

    final ClipScan scan = await scanner.scan(work);

    expect(_visible(scan.index), <String>[
      'Profiles/Work/2024-01-01.mp4',
      'Profiles/Work/old/2024-01-02.mp4',
    ]);
    expect(scan.index.profile, work);

    // A profile folder that does not exist yet has no clips.
    final ClipScan fresh = await scanner.scan(const ProfileKey('New'));
    expect(fresh.index.isEmpty, isTrue);

    // Each clip records its size and modification time.
    {
      final DateTime modified = DateTime.utc(2024, 1, 1, 20, 30, 15);
      final File file = await seedClip(
        paths,
        _default,
        LocalDay(2024, 1, 1),
        bytes: List<int>.filled(1234, 7),
      );
      await file.setLastModified(modified);

      final ClipScan scan = await scanner.scan(_default);

      expect(
        scan.index.stampOf(scan.index.clipsOn(LocalDay(2024, 1, 1)).single),
        FileStamp(sizeBytes: 1234, modifiedMs: modified.millisecondsSinceEpoch),
      );
    }
  });

  test('a legacy profile whose name holds a slash, spaces, dots, accents or '
      '"Movies" keeps its clips, sub-folders included (v1.5 names are '
      'opaque, B §5; O1; fixes E-2, F-4)', () async {
    for (final String name in <String>['Mom/Dad', 'Trip ', 'a.b', 'Café']) {
      final ProfileKey profile = ProfileKey(name);
      await seedClip(paths, profile, LocalDay(2024, 1, 5));
      await seedClip(paths, profile, LocalDay(2024, 1, 6), subFolder: 'old');

      final ClipScan scan = await scanner.scan(profile);

      expect(_visible(scan.index), <String>[
        'Profiles/$name/2024-01-05.mp4',
        'Profiles/$name/old/2024-01-06.mp4',
      ], reason: name);
      expect(scan.skippedNames, isEmpty, reason: name);
    }

    // A profile whose name contains "Movies" keeps its clips.
    {
      for (final String name in <String>['My Movies', 'MyMovies', 'Movies']) {
        final ProfileKey profile = ProfileKey(name);
        await seedClip(paths, profile, LocalDay(2026, 9, 28));

        final ClipScan scan = await scanner.scan(profile);

        expect(scan.index.clipCount, 1, reason: name);
      }
    }
  });

  test('only exact clip names count; every other .mp4 name is logged under '
      '[CALENDAR] and never empties a movie range; a scan with nothing to skip '
      'logs nothing (fixes Z-02, F-2, F-5)', () async {
    await seedClip(paths, const ProfileKey('Clean'), LocalDay(2024, 1, 1));
    await scanner.scan(const ProfileKey('Clean'));
    expect(sink.lines, isEmpty);

    await seedClip(paths, _default, LocalDay(2024, 1, 1));
    await seedClip(paths, _default, LocalDay(2024, 1, 1), ordinal: 2);
    await seedClip(
      paths,
      _default,
      LocalDay(2026, 9, 28),
      subFolder: 'my.mp4s',
    );
    for (final String junk in <String>[
      '2024-01-02.edited.mp4', // dotted name
      '2026-02-31.mp4', // impossible date
      '2024-01-02_123456.mp4', // movie temp copy of older installs
      '2024-01-02.MP4',
      '.pending-1700000000-2024-01-02.mp4',
      '2024-01-02-1.mp4',
      'notes.txt',
      '2024-01-02.mov',
    ]) {
      await seedFile(paths, junk);
    }

    final ClipScan scan = await scanner.scan(_default);

    expect(_visible(scan.index), <String>[
      '2024-01-01.mp4',
      '2024-01-01-2.mp4',
      'my.mp4s/2026-09-28.mp4',
    ]);
    expect(scan.skippedNames, <String>[
      '.pending-1700000000-2024-01-02.mp4',
      '2024-01-02-1.mp4',
      '2024-01-02.MP4',
      '2024-01-02.edited.mp4',
      '2024-01-02_123456.mp4',
      '2026-02-31.mp4',
    ]);
    expect(
      sink.lines,
      contains(
        allOf(
          startsWith('[INFO] '),
          contains(
            '[CALENDAR] Skipped 6 .mp4 files that are not clip names '
            'in profile Default: .pending-1700000000-2024-01-02.mp4, '
            '2024-01-02-1.mp4, 2024-01-02.MP4, 2024-01-02.edited.mp4, '
            '2024-01-02_123456.mp4, 2026-02-31.mp4',
          ),
        ),
      ),
    );

    // Junk names never empty a movie range: every real clip is selected with
    // its real path.
    {
      paths = await createTestPaths();
      scanner = ClipScanner(paths: paths, logger: memoryLogger(sink));
      await seedClip(paths, _default, LocalDay(2024, 1, 1));
      await seedFile(paths, '2024-01-02.edited.mp4');
      await seedClip(paths, _default, LocalDay(2024, 1, 3));
      await seedClip(
        paths,
        _default,
        LocalDay(2024, 1, 4),
        subFolder: 'my.mp4s',
      );

      final ClipScan scan = await scanner.scan(_default);

      expect(
        <String>[
          for (final ClipRef clip in scan.index.clipsFor(
            const MovieSource.preset(MoviePreset.allTime),
            today: LocalDay(2024, 1, 5),
          ))
            clip.relPath,
        ],
        <String>['2024-01-01.mp4', '2024-01-03.mp4', 'my.mp4s/2024-01-04.mp4'],
      );
    }
  });

  test('duplicates keep the shallowest path, and the hidden ones are logged '
      '(fixes Z-01)', () async {
    await seedClip(paths, _default, LocalDay(2024, 1, 1));
    await seedClip(paths, _default, LocalDay(2024, 1, 1), subFolder: 'Old');

    final ClipScan scan = await scanner.scan(_default);

    expect(_visible(scan.index), <String>['2024-01-01.mp4']);
    expect(
      sink.lines,
      contains(
        contains(
          '[CALENDAR] Hid 1 duplicate clip in profile Default: '
          'Old/2024-01-01.mp4',
        ),
      ),
    );
  });

  test('the resume gate: a profile has changed when a file was added or '
      'removed at its root or in a sub-folder, or its folder appeared; never '
      'for folders it does not own', () async {
    await seedClip(paths, _default, LocalDay(2024, 1, 1));
    final File inTrip = await seedClip(
      paths,
      _default,
      LocalDay(2024, 1, 2),
      subFolder: 'trip',
    );
    await Directory(
      paths.profileVideos(const ProfileKey('Work')),
    ).create(recursive: true);

    final ClipScan untouched = await scanner.scan(_default);
    expect(await scanner.hasChangedSince(untouched), isFalse);
    await seedFile(paths, 'Movies/OSD-Movie-1-2024-01-05.mp4');
    await seedClip(paths, const ProfileKey('Work'), LocalDay(2024, 1, 2));
    expect(await scanner.hasChangedSince(untouched), isFalse);

    final ClipScan first = await scanner.scan(_default);
    await seedClip(paths, _default, LocalDay(2024, 1, 3));
    expect(await scanner.hasChangedSince(first), isTrue);

    final ClipScan second = await scanner.scan(_default);
    await inTrip.delete();
    expect(await scanner.hasChangedSince(second), isTrue);

    final ClipScan third = await scanner.scan(_default);
    await Directory('${paths.videos}trip').delete(recursive: true);
    expect(await scanner.hasChangedSince(third), isTrue);

    final ClipScan none = await scanner.scan(const ProfileKey('New'));
    await seedClip(paths, const ProfileKey('New'), LocalDay(2024, 1, 1));
    expect(await scanner.hasChangedSince(none), isTrue);
  });

  group('unreadable folders', () {
    test('an unreadable sub-folder is skipped and logged as a warning; an '
        'unreadable profile folder is a StorageException, never an empty '
        'diary', () async {
      await seedClip(paths, _default, LocalDay(2024, 1, 1));
      await seedClip(paths, _default, LocalDay(2024, 1, 2), subFolder: 'priv');
      if (!await lockFolder('${paths.videos}priv')) return;

      final ClipScan scan = await scanner.scan(_default);

      expect(_visible(scan.index), <String>['2024-01-01.mp4']);
      expect(
        sink.lines,
        contains(
          allOf(
            startsWith('[WARNING] '),
            contains(
              '[CALENDAR] Could not list 1 folder in profile Default: priv/',
            ),
          ),
        ),
      );

      // An unreadable profile folder is a StorageException, never an empty
      // diary.
      {
        await seedClip(paths, _default, LocalDay(2024, 1, 1));
        if (!await lockFolder(paths.videos)) return;

        await expectLater(
          scanner.scan(_default),
          throwsA(isA<StorageException>()),
        );
      }
    });
  });

  test('a profile named like a date marks only the days its clip names say '
      '(fixes E-1)', () async {
    const ProfileKey dated = ProfileKey('2024-01-05');
    await seedClip(paths, dated, LocalDay(2024, 1, 1));

    final ClipScan scan = await scanner.scan(dated);

    expect(scan.index.hasDay(LocalDay(2024, 1, 1)), isTrue);
    expect(scan.index.hasDay(LocalDay(2024, 1, 5)), isFalse);
  });
}
