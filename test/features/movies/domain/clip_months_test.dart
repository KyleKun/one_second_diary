// The picker lists a profile's clips by month, the newest month first, the
// days of a month in order.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/movies/domain/clip_months.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

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

List<String> _paths(ClipMonth month) => <String>[
  for (final ClipRef clip in month.clips) clip.relPath,
];

void main() {
  test('months newest first, each with its clips by day, then ordinal, and '
      'its first and last day; an empty diary has none', () {
    final ClipIndex index = _index(<String>[
      '2026-09-02.mp4',
      '2025-12-31.mp4',
      '2026-09-01-2.mp4',
      '2026-09-01.mp4',
      '2024-02-10.mp4',
    ]);

    final List<ClipMonth> months = ClipMonths.of(index);

    expect(
      <(int, int)>[
        for (final ClipMonth month in months) (month.year, month.month),
      ],
      <(int, int)>[(2026, 9), (2025, 12), (2024, 2)],
    );
    expect(_paths(months.first), <String>[
      '2026-09-01.mp4',
      '2026-09-01-2.mp4',
      '2026-09-02.mp4',
    ]);
    expect(
      (months.last.first, months.last.last),
      (LocalDay(2024, 2, 1), LocalDay(2024, 2, 29)),
    );
    expect(ClipMonths.of(_index(<String>[])), isEmpty);
  });
}
