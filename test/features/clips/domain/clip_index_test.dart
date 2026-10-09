import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/clips/domain/month_progress.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

IndexedClip _clip(String relPath, {ProfileKey profile = _default}) =>
    IndexedClip(
      ref: ClipRef(profile: profile, relPath: relPath),
      stamp: const FileStamp(sizeBytes: 8, modifiedMs: 0),
    );

ClipIndex _index(List<String> relPaths, {ProfileKey profile = _default}) =>
    ClipIndex(
      profile: profile,
      clips: <IndexedClip>[
        for (final String relPath in relPaths) _clip(relPath, profile: profile),
      ],
    );

List<String> _paths(Iterable<ClipRef> clips) => <String>[
  for (final ClipRef clip in clips) clip.relPath,
];

void main() {
  group('lookup (E_calendar_bench proposed tests)', () {
    final ClipIndex index = _index(<String>[
      '2026-09-16.mp4',
      '2026-08-30.mp4',
      '2026-09-02.mp4',
      '2026-09-01.mp4',
      '2026-09-02-2.mp4',
    ]);

    test('counts days and clips separately (D1); answers which days have '
        "clips and lists a day's clips in ordinal order", () {
      expect(index.dayCount, 4);
      expect(index.clipCount, 5);
      expect(index.isEmpty, isFalse);

      // Which days have clips; a day's clips in ordinal order.
      {
        expect(index.hasDay(LocalDay(2026, 9, 16)), isTrue);
        expect(index.hasDay(LocalDay(2026, 9, 15)), isFalse);
        expect(index.firstDay, LocalDay(2026, 8, 30));
        expect(index.lastDay, LocalDay(2026, 9, 16));
        expect(_paths(index.clipsOn(LocalDay(2026, 9, 2))), <String>[
          '2026-09-02.mp4',
          '2026-09-02-2.mp4',
        ]);
        expect(index.clipsOn(LocalDay(2026, 9, 3)), isEmpty);
      }
    });
  });

  group('month views', () {
    final ClipIndex index = _index(<String>[
      '2026-08-30.mp4',
      '2026-09-01.mp4',
      '2026-09-02.mp4',
      '2026-09-02-2.mp4',
      '2026-09-16.mp4',
      '2026-09-29.mp4', // after "today": a wrong clock, never counted
    ]);
    final LocalDay today = LocalDay(2026, 9, 28);

    test(
      'month summary: "N of M days" through today (D1); clips per month count '
      'clips, not days (M2); newest first walks days and their clips '
      'backwards (D3 feed)',
      () {
        final MonthProgress current = index.monthSummary(
          year: 2026,
          month: 9,
          today: today,
        );
        expect((current.recorded, current.elapsed), (3, 28));
        final MonthProgress past = index.monthSummary(
          year: 2026,
          month: 8,
          today: today,
        );
        expect((past.recorded, past.elapsed), (1, 31));
        final MonthProgress future = index.monthSummary(
          year: 2026,
          month: 10,
          today: today,
        );
        expect((future.recorded, future.elapsed), (0, 0));
        final MonthProgress leap = index.monthSummary(
          year: 2024,
          month: 2,
          today: today,
        );
        expect((leap.recorded, leap.elapsed), (0, 29));

        final List<int> counts = index.clipsPerMonth(2026);
        expect(counts, hasLength(12));
        expect(counts[7], 1); // August
        expect(counts[8], 5); // September: 4 days, 5 clips
        expect(counts[0], 0);
        expect(index.clipsPerMonth(2025), List<int>.filled(12, 0));

        // Newest first walks days and their clips backwards.
        {
          expect(_paths(index.newestFirst), <String>[
            '2026-09-29.mp4',
            '2026-09-16.mp4',
            '2026-09-02-2.mp4',
            '2026-09-02.mp4',
            '2026-09-01.mp4',
            '2026-08-30.mp4',
          ]);
        }
      },
    );
  });

  group('day ranges', () {
    final ClipIndex index = _index(<String>[
      '2026-03-27.mp4',
      '2026-03-28.mp4',
      '2026-03-29.mp4', // Europe springs forward: a 23-hour day
      '2026-03-29-2.mp4',
      '2026-03-30.mp4',
      '2026-04-02.mp4',
    ]);
    final DayRange week = DayRange(
      first: LocalDay(2026, 3, 28),
      last: LocalDay(2026, 4, 1),
    );

    test('selects whole days in order, clips in ordinal order, across a DST '
        'change (fixes F-1, F-3); skipped days are the days without a clip, '
        'never after today (M5)', () {
      expect(_paths(index.clipsIn(week)), <String>[
        '2026-03-28.mp4',
        '2026-03-29.mp4',
        '2026-03-29-2.mp4',
        '2026-03-30.mp4',
      ]);
      expect(index.countClipsIn(week), 4);

      final DayRange empty = DayRange(
        first: LocalDay(2026, 4, 1),
        last: LocalDay(2026, 3, 1),
      );
      expect(empty.isEmpty, isTrue);
      expect(index.clipsIn(empty), isEmpty);
      expect(index.countClipsIn(empty), 0);

      // Skipped days are the days of the range without a clip, never after
      // today.
      {
        expect(index.skippedDays(week, today: LocalDay(2026, 4, 5)), <LocalDay>[
          LocalDay(2026, 3, 31),
          LocalDay(2026, 4, 1),
        ]);
        expect(
          index.skippedDays(week, today: LocalDay(2026, 3, 31)),
          <LocalDay>[LocalDay(2026, 3, 31)],
        );
      }
    });
  });

  group('previous / next recorded clip (D4 chevrons, player neighbours)', () {
    final ClipIndex index = _index(<String>[
      '2026-08-30.mp4',
      '2026-09-01.mp4',
      '2026-09-02.mp4',
      '2026-09-02-2.mp4',
      '2026-09-02-3.mp4',
      '2026-09-16.mp4',
    ]);
    ClipRef ref(String relPath) => ClipRef(profile: _default, relPath: relPath);

    test("steps through a day's clips before moving to the next day (D1), "
        'stops at both ends, works from a clip no longer in the index and '
        'finds the recorded day before a missed day', () {
      expect(index.nextClip(ref('2026-09-01.mp4'))?.relPath, '2026-09-02.mp4');
      expect(
        index.nextClip(ref('2026-09-02.mp4'))?.relPath,
        '2026-09-02-2.mp4',
      );
      expect(
        index.nextClip(ref('2026-09-02-3.mp4'))?.relPath,
        '2026-09-16.mp4',
      );
      expect(
        index.previousClip(ref('2026-09-16.mp4'))?.relPath,
        '2026-09-02-3.mp4',
      );
      expect(
        index.previousClip(ref('2026-09-02-2.mp4'))?.relPath,
        '2026-09-02.mp4',
      );
      expect(
        index.previousClip(ref('2026-09-02.mp4'))?.relPath,
        '2026-09-01.mp4',
      );

      // Edges, a clip not in the index, a missed day.
      {
        expect(index.previousClip(ref('2026-08-30.mp4')), isNull);
        expect(index.nextClip(ref('2026-09-16.mp4')), isNull);
        expect(
          index.nextClip(ref('2026-09-10.mp4'))?.relPath,
          '2026-09-16.mp4',
        );
        expect(
          index.previousClip(ref('2026-09-10.mp4'))?.relPath,
          '2026-09-02-3.mp4',
        );
        expect(
          index.previousRecordedDay(LocalDay(2026, 9, 16)),
          LocalDay(2026, 9, 2),
        );
        expect(index.previousRecordedDay(LocalDay(2026, 8, 30)), isNull);
      }
    });
  });

  group('copy-on-write patches', () {
    final ClipIndex index = _index(<String>[
      '2026-09-01.mp4',
      '2026-09-02.mp4',
      'Old/2026-09-02.mp4',
    ]);
    const FileStamp newer = FileStamp(sizeBytes: 99, modifiedMs: 1);

    IndexedClip withStamp(String relPath, FileStamp stamp) => IndexedClip(
      ref: ClipRef(profile: _default, relPath: relPath),
      stamp: stamp,
    );

    test('a new clip of a day takes 1 + the highest ordinal of that day in the '
        'whole profile (CONTRACTS §4 rule a); adding, removing and replacing '
        'return new snapshots and keep the original intact; removing a clip '
        'brings back the duplicate it hid', () {
      final ClipIndex trip = _index(<String>['trip/2024-01-05.mp4']);

      expect(trip.nextOrdinal(LocalDay(2024, 1, 5)), 2);
      expect(trip.nextOrdinal(LocalDay(2024, 1, 6)), 1);
      expect(
        trip
            .withClip(_clip('2024-01-05-2.mp4'))
            .nextOrdinal(LocalDay(2024, 1, 5)),
        3,
      );
      // Gaps: the highest ordinal, not the number of clips, so ordinal
      // order stays recording order.
      final LocalDay day = LocalDay(2024, 1, 5);

      expect(
        _index(<String>['2024-01-05.mp4', '2024-01-05-4.mp4']).nextOrdinal(day),
        5,
      );
      expect(_index(<String>['2024-01-05-2.mp4']).nextOrdinal(day), 3);
      expect(_index(<String>['trip/2024-01-05-3.mp4']).nextOrdinal(day), 4);

      // Copy-on-write patches.
      {
        final ClipIndex added = index.withClip(_clip('2026-09-20.mp4'));
        final ClipIndex removed = added.withoutClip('2026-09-01.mp4');

        expect(index.hasDay(LocalDay(2026, 9, 20)), isFalse);
        expect(added.hasDay(LocalDay(2026, 9, 20)), isTrue);
        expect(removed.hasDay(LocalDay(2026, 9, 1)), isFalse);
        expect(removed.clipCount, 2);
        expect(
          identical(index.withoutClip('nope/2026-01-01.mp4'), index),
          isTrue,
        );

        final ClipIndex replaced = index.withClip(
          withStamp('2026-09-01.mp4', newer),
        );
        final ClipRef clip = replaced.clipsOn(LocalDay(2026, 9, 1)).single;

        expect(replaced.stampOf(clip), newer);
        expect(
          index.stampOf(clip),
          const FileStamp(sizeBytes: 8, modifiedMs: 0),
        );
        expect(replaced.clipCount, index.clipCount);

        // Removing a clip brings back the duplicate it hid, as a rescan would.
        {
          final ClipIndex removed = index.withoutClip('2026-09-02.mp4');

          expect(_paths(removed.clipsOn(LocalDay(2026, 9, 2))), <String>[
            'Old/2026-09-02.mp4',
          ]);
          expect(removed.hiddenDuplicates, isEmpty);
        }
      }
    });
  });

  group('snapshot identity', () {
    test('same files compares relPaths and stamps, not instances; '
        'changedSince names the visible clips that are new, rewritten or no '
        'longer hidden, newest first', () {
      final ClipIndex a = _index(<String>[
        '2024-01-01.mp4',
        'x/2024-01-01.mp4',
      ]);
      final ClipIndex b = _index(<String>[
        'x/2024-01-01.mp4',
        '2024-01-01.mp4',
      ]);
      final ClipIndex touched = a.withClip(
        IndexedClip(
          ref: ClipRef(profile: _default, relPath: '2024-01-01.mp4'),
          stamp: const FileStamp(sizeBytes: 8, modifiedMs: 5),
        ),
      );

      expect(a.hasSameFilesAs(b), isTrue);
      expect(a.hasSameFilesAs(touched), isFalse);
      expect(a.hasSameFilesAs(a.withoutClip('x/2024-01-01.mp4')), isFalse);
      expect(
        ClipIndex.empty(
          _default,
        ).hasSameFilesAs(ClipIndex.empty(const ProfileKey('Work'))),
        isFalse,
      );

      // changedSince: a queue fed every snapshot only looks at what changed.
      {
        final ClipIndex before = _index(<String>[
          '2024-01-01.mp4',
          '2024-01-02.mp4',
          '2024-01-03.mp4',
          'x/2024-01-03.mp4',
        ]);
        final ClipIndex after = before
            .withClip(_clip('2024-01-05.mp4'))
            .withClip(_clip('2024-01-04.mp4'))
            .withClip(
              IndexedClip(
                ref: ClipRef(profile: _default, relPath: '2024-01-01.mp4'),
                stamp: const FileStamp(sizeBytes: 9, modifiedMs: 5),
              ),
            )
            .withoutClip('2024-01-03.mp4'); // shows x/2024-01-03.mp4

        expect(_paths(after.changedSince(before)), <String>[
          '2024-01-05.mp4',
          '2024-01-04.mp4',
          'x/2024-01-03.mp4',
          '2024-01-01.mp4',
        ]);
        expect(after.changedSince(after), isEmpty);
        // A rescan builds new entries: equal ones are not changes.
        expect(
          _index(<String>['2024-01-02.mp4']).changedSince(before),
          isEmpty,
        );
      }
    });
  });

  group('duplicates of one (day, ordinal) (CONTRACTS §4 rule b, Z-01)', () {
    test('the shallowest path wins, ties go to the smallest relPath; a root '
        'clip hides its sub-folder copy, so a movie never gets the same day '
        'twice; depth counts from the profile folder', () {
      final ClipIndex index = _index(<String>[
        'trip/deep/2024-01-01.mp4',
        'trip/2024-01-01.mp4',
        'Old/2024-01-01.mp4',
        'b/2024-01-02.mp4',
        'a/2024-01-02.mp4',
        '2024-01-03.mp4',
      ]);

      expect(_paths(index.clipsOn(LocalDay(2024, 1, 1))), <String>[
        'Old/2024-01-01.mp4',
      ]);
      expect(_paths(index.clipsOn(LocalDay(2024, 1, 2))), <String>[
        'a/2024-01-02.mp4',
      ]);
      expect(index.clipCount, 3);
      expect(_paths(index.hiddenDuplicates), <String>[
        'b/2024-01-02.mp4',
        'trip/2024-01-01.mp4',
        'trip/deep/2024-01-01.mp4',
      ]);

      // A root clip hides its sub-folder copy.
      {
        final ClipIndex index = _index(<String>[
          'Old/2024-01-01.mp4',
          '2024-01-01.mp4',
          '2024-01-01-2.mp4',
        ]);

        expect(_paths(index.clipsOn(LocalDay(2024, 1, 1))), <String>[
          '2024-01-01.mp4',
          '2024-01-01-2.mp4',
        ]);

        // Depth counts from the profile folder, not from the videos root.
        const ProfileKey work = ProfileKey('Work');
        final ClipIndex workIndex = _index(<String>[
          'Profiles/Work/b/2024-01-01.mp4',
          'Profiles/Work/2024-01-01.mp4',
        ], profile: work);

        expect(_paths(workIndex.clipsOn(LocalDay(2024, 1, 1))), <String>[
          'Profiles/Work/2024-01-01.mp4',
        ]);
      }
    });
  });
}
