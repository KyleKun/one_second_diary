import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/clips/domain/journey_stats.dart';
import 'package:one_second_diary/features/clips/domain/month_progress.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

ClipIndex _index(List<String> relPaths) => ClipIndex(
  profile: ProfileKey.defaultProfile,
  clips: <IndexedClip>[
    for (final String relPath in relPaths)
      IndexedClip(
        ref: ClipRef(profile: ProfileKey.defaultProfile, relPath: relPath),
        stamp: const FileStamp(sizeBytes: 8, modifiedMs: 0),
      ),
  ],
);

void main() {
  final LocalDay today = LocalDay(2026, 9, 28);
  final ClipIndex index = _index(<String>[
    '2024-03-12.mp4',
    '2024-03-13.mp4',
    '2024-03-14.mp4',
    '2026-09-26.mp4',
    '2026-09-27.mp4',
    '2026-09-27-2.mp4',
  ]);

  test('derives every J1 tile from the index, counting days, not clips', () {
    final JourneyStats stats = JourneyStats.of(
      index,
      today: today,
      metaOf: (ClipRef clip) => const ClipMeta(durationMs: 2000),
    );

    expect(stats.daysRecorded, 5);
    expect(stats.firstDay, LocalDay(2024, 3, 12));
    expect(stats.currentStreak, 2); // today not yet recorded: still alive
    expect(stats.streakAtRisk, isTrue);
    expect(stats.longestStreak, 3);
    expect(stats.thisMonth, const MonthProgress(recorded: 2, elapsed: 28));
    expect(stats.lifeSoFar, const Duration(seconds: 12));
    expect(stats.lifeSoFarIsEstimate, isFalse);
  });

  test('while the backfill is incomplete, unknown clips are estimated at '
      'the average known duration (one second when none is known) and '
      'flagged; an empty diary is zeros, not an estimate', () {
    final JourneyStats partly = JourneyStats.of(
      index,
      today: today,
      metaOf: (ClipRef clip) => switch (clip.relPath) {
        '2026-09-26.mp4' => const ClipMeta(durationMs: 1000),
        '2026-09-27.mp4' => const ClipMeta(durationMs: 3000),
        _ => null,
      },
    );
    expect(partly.lifeSoFar, const Duration(seconds: 12));
    expect(partly.lifeSoFarIsEstimate, isTrue);

    final JourneyStats none = JourneyStats.of(
      index,
      today: today,
      metaOf: (ClipRef clip) => const ClipMeta(),
    );
    expect(none.lifeSoFar, const Duration(seconds: 6));
    expect(none.lifeSoFarIsEstimate, isTrue);

    final JourneyStats empty = JourneyStats.of(
      ClipIndex.empty(ProfileKey.defaultProfile),
      today: today,
      metaOf: (ClipRef clip) => null,
    );
    expect(empty.daysRecorded, 0);
    expect(empty.firstDay, isNull);
    expect(empty.currentStreak, 0);
    expect(empty.thisMonth, const MonthProgress(recorded: 0, elapsed: 28));
    expect(empty.lifeSoFar, Duration.zero);
    expect(empty.lifeSoFarIsEstimate, isFalse);
  });
}
