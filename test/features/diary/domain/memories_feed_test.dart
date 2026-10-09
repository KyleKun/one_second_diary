// The Memories feed: every month with a clip, newest first, each heading
// its recorded days, newest first. Built from the index's sorted days
// without touching every clip, and indexed in O(log n), so the feed's list
// builds only the rows on screen.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/diary/domain/memories_feed.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../support/diary_fixtures.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

List<MemoriesRow> rowsOf(MemoriesFeed feed) => <MemoriesRow>[
  for (int i = 0; i < feed.length; i++) feed[i],
];

void main() {
  test('heads each month with a clip, newest first, and lists its days '
      'newest first; months without clips are left out; finds the row of a '
      'recorded day, and none for another; built once per snapshot', () {
    final ClipIndex index = diaryIndex(_default, <LocalDay, int>{
      LocalDay(2025, 12, 31): 1,
      LocalDay(2026, 6, 30): 1,
      LocalDay(2026, 9, 1): 2,
      LocalDay(2026, 9, 27): 1,
      LocalDay(2026, 9, 28): 1,
    });
    final MemoriesFeed feed = MemoriesFeed.of(index);

    expect(rowsOf(feed), <MemoriesRow>[
      const MemoriesMonthRow(DiaryMonth(2026, 9)),
      MemoriesDayRow(LocalDay(2026, 9, 28)),
      MemoriesDayRow(LocalDay(2026, 9, 27)),
      MemoriesDayRow(LocalDay(2026, 9, 1)),
      const MemoriesMonthRow(DiaryMonth(2026, 6)),
      MemoriesDayRow(LocalDay(2026, 6, 30)),
      const MemoriesMonthRow(DiaryMonth(2025, 12)),
      MemoriesDayRow(LocalDay(2025, 12, 31)),
    ]);
    expect(feed.monthAt(2), const DiaryMonth(2026, 9));
    expect(feed.monthAt(5), const DiaryMonth(2026, 6));
    expect(feed.indexOfDay(LocalDay(2026, 9, 1)), 3);
    expect(feed.indexOfDay(LocalDay(2025, 12, 31)), 7);
    expect(feed.indexOfDay(LocalDay(2026, 9, 2)), isNull);
    expect(feed.indexOfDay(LocalDay(2024, 1, 3)), isNull);
    expect(MemoriesFeed.of(index), same(feed));
    expect(MemoriesFeed.of(ClipIndex.empty(_default)).isEmpty, isTrue);
  });

  test('in two columns (tablets), pairs each month\'s days, newest first; '
      'a month\'s last odd day is alone', () {
    final MemoriesFeed feed = MemoriesFeed.of(
      diaryIndex(_default, <LocalDay, int>{
        LocalDay(2026, 6, 30): 1,
        LocalDay(2026, 9, 1): 2,
        LocalDay(2026, 9, 27): 1,
        LocalDay(2026, 9, 28): 1,
      }),
      columns: 2,
    );

    expect(rowsOf(feed), <MemoriesRow>[
      const MemoriesMonthRow(DiaryMonth(2026, 9)),
      MemoriesDayRow.of(<LocalDay>[
        LocalDay(2026, 9, 28),
        LocalDay(2026, 9, 27),
      ]),
      MemoriesDayRow(LocalDay(2026, 9, 1)),
      const MemoriesMonthRow(DiaryMonth(2026, 6)),
      MemoriesDayRow(LocalDay(2026, 6, 30)),
    ]);
    expect(feed.indexOfDay(LocalDay(2026, 9, 27)), 1);
    expect(feed.indexOfDay(LocalDay(2026, 9, 1)), 2);
    expect(feed.indexOfDay(LocalDay(2026, 6, 30)), 4);
    expect(feed.monthAt(4), const DiaryMonth(2026, 6));
  });

  test('over 5 000 days, builds and answers without walking the clips', () {
    // The best of several rounds, each over a snapshot of its own (a feed
    // is kept per snapshot); the first round warms the JIT up, and a GC
    // pause on a loaded machine spoils one round, not the budget.
    const int rounds = 5;
    final List<ClipIndex> snapshots = <ClipIndex>[
      for (int round = 0; round <= rounds; round++)
        diaryIndex(_default, <LocalDay, int>{
          for (int i = 0; i < 5000; i++) LocalDay(2012, 1, 1).addDays(i): 1,
        }),
    ];
    Duration best = const Duration(days: 1);
    late MemoriesFeed feed;
    late List<MemoriesRow> sampled;

    for (int round = 0; round <= rounds; round++) {
      final Stopwatch watch = Stopwatch()..start();
      feed = MemoriesFeed.of(snapshots[round]);
      sampled = <MemoriesRow>[
        for (int i = 0; i < feed.length; i += 97) feed[i],
      ];
      watch.stop();
      if (round > 0 && watch.elapsed < best) best = watch.elapsed;
    }

    expect(sampled.first, const MemoriesMonthRow(DiaryMonth(2025, 9)));
    expect(feed.length, 5000 + 165);
    expect(best, lessThan(const Duration(milliseconds: 50)));
  });
}
