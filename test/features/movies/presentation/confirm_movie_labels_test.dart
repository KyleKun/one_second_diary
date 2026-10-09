// The confirmation's title for days picked: the year once, unless the days
// span two; one day is just that day.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/movies/domain/movie_draft.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/confirm_movie_labels.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../shared/fakes/clip_index_fixture.dart';
import '../support/pump_localized_osd.dart';

void main() {
  testWidgets('a date-range movie is titled by its first and last day', (
    WidgetTester tester,
  ) async {
    late BuildContext context;
    await pumpLocalizedOsd(
      tester,
      Builder(
        builder: (BuildContext c) {
          context = c;
          return const SizedBox.shrink();
        },
      ),
    );
    final LocalDay today = LocalDay(2026, 9, 28);
    String titleOf(LocalDay first, LocalDay last) => ConfirmMovieLabels.title(
      context,
      MovieDraft.of(
        clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[first, last]),
        MovieSource.dateRange(DayRange(first: first, last: last)),
        today: today,
      ),
    );

    expect(
      titleOf(LocalDay(2026, 9, 3), LocalDay(2026, 9, 12)),
      'Sep 3 – Sep 12, 2026',
    );
    expect(
      titleOf(LocalDay(2026, 8, 30), LocalDay(2026, 9, 2)),
      'Aug 30 – Sep 2, 2026',
    );
    expect(
      titleOf(LocalDay(2025, 12, 28), LocalDay(2026, 1, 3)),
      'Dec 28, 2025 – Jan 3, 2026',
    );
    expect(titleOf(LocalDay(2026, 9, 3), LocalDay(2026, 9, 3)), 'Sep 3, 2026');
  });
}
