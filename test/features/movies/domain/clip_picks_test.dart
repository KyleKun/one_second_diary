// The clips picked by hand, so a tile knows at once whether it is picked.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/movies/domain/clip_picks.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

ClipRef _clip(int month, int day, {int ordinal = 1}) => ClipRef(
  profile: ProfileKey.defaultProfile,
  relPath:
      '${LocalDay(2026, month, day).fileStem}'
      '${ordinal == 1 ? '' : '-$ordinal'}.mp4',
);

void main() {
  test('a tap picks a clip and a second tap unpicks it; a whole month is '
      'added or removed at once; only the clips still in the diary stay '
      'picked', () {
    const ClipPicks none = ClipPicks.none();
    expect((none.count, none.contains(_clip(9, 1))), (0, false));

    final ClipPicks one = none.toggle(_clip(9, 1));
    final ClipPicks two = one.toggle(_clip(9, 2, ordinal: 2));
    expect(one.contains(_clip(9, 1)), isTrue);
    expect(two.count, 2);
    expect(two.toggle(_clip(9, 1)).contains(_clip(9, 1)), isFalse);
    expect(one.count, 1, reason: 'a pick makes a new selection');

    final List<ClipRef> september = <ClipRef>[
      for (int day = 1; day <= 3; day++) _clip(9, day),
    ];
    final ClipPicks months = none
        .toggle(_clip(8, 31))
        .toggle(_clip(9, 2))
        .adding(september);
    expect(months.count, 4, reason: 'Sep 2 is counted once');
    final ClipPicks without = months.removing(september);
    expect((without.count, without.contains(_clip(8, 31))), (1, true));

    expect(months.where((ClipRef clip) => clip != _clip(8, 31)).count, 3);
  });
}
