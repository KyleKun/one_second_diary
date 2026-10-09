// ignore_for_file: file_names

// "Choose dates" in Create movie: the sheet opens on this month, two taps
// pick the first and last day (across a month page), and Continue makes
// the movie of exactly those days.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_stats_bento.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/range_day_cell.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

void main() {
  /// Default: December 2023, every day, and January 1 to 5, 2024 (today).
  Future<AppRobot> launch(WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: (AppPaths paths) async {
        for (int day = 1; day <= 31; day++) {
          await seedClip(paths, _default, LocalDay(2023, 12, day));
        }
        for (int day = 1; day <= 5; day++) {
          await seedClip(paths, _default, LocalDay(2024, 1, day));
        }
      },
    );
    await app.shell.tapTab(AppRoute.journey);
    await app.harness.settleUntil(
      () => app.journey.hasNumber(JourneyTile.daysRecorded),
      reason: 'the diary was read',
    );
    return app;
  }

  testWidgets('Choose dates picks Dec 28 to Jan 3 across the month page and '
      'makes the movie of those 7 days', (WidgetTester tester) async {
    final AppRobot app = await launch(tester);
    await app.journey.tapCreateMovie();

    await app.movies.tapChooseDates();
    expect(app.movies.datesSheetShown, isTrue);
    expect(app.movies.datesMonth, 'January 2024');
    expect(app.movies.canContinueDates, isFalse);

    await app.movies.tapPreviousDatesMonth();
    expect(app.movies.datesMonth, 'December 2023');
    await app.movies.tapDay(LocalDay(2023, 12, 28));
    expect(app.movies.datesCount, Strings.movieDatePickEnd);
    expect(app.movies.dayPart(LocalDay(2023, 12, 28)), RangeDayPart.start);

    await app.movies.tapDay(LocalDay(2023, 12, 30));
    expect(app.movies.datesCount, Strings.movieClipsFound(3));
    expect(app.movies.dayPart(LocalDay(2023, 12, 29)), RangeDayPart.between);
    expect(app.movies.dayPart(LocalDay(2023, 12, 30)), RangeDayPart.end);
    expect(app.movies.canContinueDates, isTrue);

    await app.movies.tapDatesContinue();
    expect(app.movies.datesSheetShown, isFalse);
    app.shell.expectAt(AppRoute.confirmMovie);
    expect(app.movies.confirmTitle, 'Dec 28 – Dec 30, 2023');
    expect(
      app.movies.confirmSummary,
      Strings.movieSummary(
        clips: Strings.clipCount(3),
        profile: Strings.defaultProfile,
        orientation: Strings.landscape,
      ),
    );
    app.expectNoPluginChannel();
  });
}
