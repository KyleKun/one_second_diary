// Before a movie starts, the phone must have the normalised copies plus
// the movie twice free, over the 200 MB floor);
// otherwise it fails early, before any work. Without the clips' facts the
// copies are a tenth of the clips, the 2.1× of earlier versions.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/storage_budget.dart';
import 'package:one_second_diary/features/movies/domain/movie_space.dart';

void main() {
  test('a movie needs its normalised copies plus twice its clips (2.1× '
      'when the copies are not known); what is missing is nothing when '
      'enough is free over the floor or the free space is unknown, else '
      'the difference', () {
    expect(MovieSpace.neededFor(1000), 2100);
    expect(MovieSpace.neededFor(1000, normalisedBytes: 500), 2500);
    expect(MovieSpace.neededFor(1), 3);
    expect(MovieSpace.neededFor(0), 0);

    const int floor = StorageBudget.floorBytes;
    expect(MovieSpace.shortfall(needed: 2100, free: floor + 5000), isNull);
    expect(MovieSpace.shortfall(needed: 2100, free: floor + 2100), isNull);
    expect(MovieSpace.shortfall(needed: 2100, free: null), isNull);
    expect(MovieSpace.shortfall(needed: 2100, free: floor + 600), 1500);
  });
}
