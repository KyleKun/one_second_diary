import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/domain/movie_selection.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

LocalDay d(int y, int m, int day) => LocalDay(y, m, day);

ClipIndex _index(Iterable<String> relPaths) => ClipIndex(
  profile: ProfileKey.defaultProfile,
  clips: <IndexedClip>[
    for (final String relPath in relPaths)
      IndexedClip(
        ref: ClipRef(profile: ProfileKey.defaultProfile, relPath: relPath),
        stamp: const FileStamp(sizeBytes: 8, modifiedMs: 0),
      ),
  ],
);

ClipIndex _daysBack(LocalDay today, int count) => _index(<String>[
  for (int i = 0; i < count; i++) '${today.addDays(-i).fileStem}.mp4',
]);

List<String> _paths(List<ClipRef> clips) => <String>[
  for (final ClipRef clip in clips) clip.relPath,
];

void main() {
  final LocalDay today = d(2026, 9, 28);

  // "Last N days" is today and the N - 1 days before; "this month" and "this
  // year" run through today; "last year" is the whole previous calendar year.
  test('the presets are the M1 choices and cover the days v1.7 selected; a '
      'month is clamped to today', () {
    expect(MoviePreset.values.map((MoviePreset p) => p.name), <String>[
      'allTime',
      'last7Days',
      'last30Days',
      'thisMonth',
      'thisYear',
      'lastYear',
    ]);

    final LocalDay firstRecorded = d(2024, 3, 12);
    final Map<MoviePreset, (LocalDay, LocalDay)> expected =
        <MoviePreset, (LocalDay, LocalDay)>{
          MoviePreset.allTime: (firstRecorded, today),
          MoviePreset.last7Days: (d(2026, 9, 22), today),
          MoviePreset.last30Days: (d(2026, 8, 30), today),
          MoviePreset.thisMonth: (d(2026, 9, 1), today),
          MoviePreset.thisYear: (d(2026, 1, 1), today),
          MoviePreset.lastYear: (d(2025, 1, 1), d(2025, 12, 31)),
        };
    for (final MapEntry<MoviePreset, (LocalDay, LocalDay)>(
          key: MoviePreset preset,
          value: (LocalDay first, LocalDay last),
        )
        in expected.entries) {
      final DayRange r = MovieRanges.preset(
        preset,
        today: today,
        firstRecorded: firstRecorded,
      );
      expect((r.first, r.last), (first, last), reason: preset.name);
    }

    expect(MovieRanges.month(2026, 9, today: today).last, today);
    final DayRange dec = MovieRanges.month(2025, 12, today: today);
    expect((dec.first, dec.last), (d(2025, 12, 1), d(2025, 12, 31)));
    expect(MovieRanges.month(2024, 2, today: today).last, d(2024, 2, 29));
  });

  test('last 7 and last 30 days hold 7 and 30 days across a spring-forward, '
      'in any time zone (fixes F-3, F-1)', () {
    // Europe sprang forward on 03-29, Chile on 09-06.
    final List<(LocalDay, MoviePreset, int, String)> rows =
        <(LocalDay, MoviePreset, int, String)>[
          (d(2026, 4, 2), MoviePreset.last7Days, 7, '2026-03-27.mp4'),
          (d(2026, 9, 28), MoviePreset.last30Days, 30, '2026-08-30.mp4'),
        ];
    for (final (LocalDay day, MoviePreset preset, int days, String first)
        in rows) {
      final ClipIndex index = _daysBack(day, 302);
      final MovieSource source = MovieSource.preset(preset);

      final List<ClipRef> clips = index.clipsFor(source, today: day);
      expect(clips.first.relPath, first, reason: preset.name);
      expect(clips, hasLength(days), reason: preset.name);
      expect(index.countClipsFor(source, today: day), days);
    }
  });

  test('a range plays every clip of each day in ordinal order, with its real '
      'path, and a hidden duplicate never (fixes Z-01); a month runs through '
      'today; an empty diary selects nothing', () {
    final ClipIndex index = _index(<String>[
      '2024-01-01.mp4',
      'Old/2024-01-01.mp4',
      '2024-01-01-2.mp4',
      'Backup/2024-01-02.mp4',
    ]);
    expect(
      _paths(
        index.clipsFor(
          const MovieSource.preset(MoviePreset.allTime),
          today: d(2024, 1, 3),
        ),
      ),
      <String>['2024-01-01.mp4', '2024-01-01-2.mp4', 'Backup/2024-01-02.mp4'],
    );

    final ClipIndex september = _index(<String>[
      '2026-08-31.mp4',
      '2026-09-01.mp4',
      '2026-09-28.mp4',
      '2026-09-29.mp4', // tomorrow: a wrong clock
    ]);
    expect(
      _paths(
        september.clipsFor(
          const MovieSource.month(year: 2026, month: 9),
          today: today,
        ),
      ),
      <String>['2026-09-01.mp4', '2026-09-28.mp4'],
    );

    expect(
      ClipIndex.empty(
        ProfileKey.defaultProfile,
      ).clipsFor(const MovieSource.preset(MoviePreset.allTime), today: today),
      isEmpty,
    );
  });

  test('picked clips play by day and ordinal, never in tap order, and only '
      'while they are still in the index', () {
    final ClipIndex index = _index(<String>[
      '2024-01-01.mp4',
      '2024-01-01-2.mp4',
      '2024-01-05.mp4',
    ]);
    ClipRef ref(String relPath) =>
        ClipRef(profile: ProfileKey.defaultProfile, relPath: relPath);

    final MovieSource picked = MovieSource.custom(<ClipRef>{
      ref('2024-01-05.mp4'),
      ref('2024-01-01-2.mp4'),
      ref('2024-01-03.mp4'), // deleted since it was picked
      ref('2024-01-01.mp4'),
    });
    expect(_paths(index.clipsFor(picked, today: d(2024, 1, 9))), <String>[
      '2024-01-01.mp4',
      '2024-01-01-2.mp4',
      '2024-01-05.mp4',
    ]);
    expect(index.countClipsFor(picked, today: d(2024, 1, 9)), 3);
    expect(index.rangeOf(picked, today: d(2024, 1, 9)), isNull);
  });
}
