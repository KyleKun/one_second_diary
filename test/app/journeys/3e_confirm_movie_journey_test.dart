// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_stats_bento.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/harness/seeds.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

const ProfileKey _default = ProfileKey.defaultProfile;
const ProfileKey _trip = ProfileKey('Trip');

void main() {
  /// Default: December 2023 but the 9th, 21st and 25th; January 1, 2 and
  /// 4, 2024 (today is the 5th); November 30, 2023 alone. Trip (portrait):
  /// December 1 to 3.
  Future<AppRobot> launch(WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: prefsWithProfiles(const <ProfileSeed>[
        ProfileSeed('Trip', orientation: 'portrait'),
      ]),
      seed: (AppPaths paths) async {
        await seedClip(paths, _default, LocalDay(2023, 11, 30));
        for (int day = 1; day <= 31; day++) {
          if (day == 9 || day == 21 || day == 25) continue;
          await seedClip(paths, _default, LocalDay(2023, 12, day));
        }
        for (final int day in <int>[1, 2, 4]) {
          await seedClip(paths, _default, LocalDay(2024, 1, day));
        }
        for (int day = 1; day <= 3; day++) {
          await seedClip(paths, _trip, LocalDay(2023, 12, day));
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

  testWidgets("the Diary's Make movie: the month, its clips and the days "
      'without a video; back to the Diary', (WidgetTester tester) async {
    final AppRobot app = await launch(tester);
    await app.shell.tapTab(AppRoute.diary);

    await app.shell.open(
      const CreateMovieArgs(source: MovieSource.month(year: 2023, month: 12)),
    );

    app.shell.expectAt(AppRoute.confirmMovie);
    expect(app.movies.confirmTitle, 'December 2023');
    expect(
      app.movies.confirmSummary,
      Strings.movieSummary(
        clips: Strings.clipCount(28),
        profile: Strings.defaultProfile,
        orientation: Strings.landscape,
      ),
    );
    expect(
      app.movies.confirmCallout,
      Strings.movieSkippedDays(3, days: '9, 21, 25'),
    );
    expect(app.movies.canCreateMovie, isTrue);

    await app.shell.pressBack();
    app.shell.expectAt(AppRoute.diary);
    app.expectNoPluginChannel();
  });

  testWidgets('this month stops at today; a month with one clip cannot make '
      'a movie', (WidgetTester tester) async {
    final AppRobot app = await launch(tester);
    await app.shell.tapTab(AppRoute.diary);

    await app.shell.open(
      const CreateMovieArgs(source: MovieSource.month(year: 2024, month: 1)),
    );
    expect(app.movies.confirmTitle, 'January 2024');
    expect(
      app.movies.confirmCallout,
      Strings.movieSkippedDays(2, days: '3, 5'),
      reason: 'today counts; tomorrow does not',
    );
    await app.shell.pressBack();

    await app.shell.open(
      const CreateMovieArgs(source: MovieSource.month(year: 2023, month: 11)),
    );
    expect(app.movies.confirmCallout, Strings.movieInsufficientVideos);
    expect(app.movies.canCreateMovie, isFalse);
    app.expectNoPluginChannel();
  });

  testWidgets("M1's range lands on its confirmation; the chip makes it of "
      "Trip's clips in place", (WidgetTester tester) async {
    final AppRobot app = await launch(tester);
    await app.journey.tapCreateMovie();
    await app.movies.pickPreset(MoviePreset.last30Days);

    await app.movies.tapContinue();

    app.shell.expectAt(AppRoute.confirmMovie);
    expect(app.movies.confirmTitle, 'Dec 7, 2023 – Jan 5, 2024');

    await app.movies.tapProfileChip();
    await app.profileSheet.tap(_trip);

    app.shell.expectAt(AppRoute.confirmMovie);
    expect(
      app.movies.confirmSummary,
      Strings.movieSummary(
        clips: Strings.clipCount(0),
        profile: 'Trip',
        orientation: Strings.portrait,
      ),
      reason: "Trip's clips are older than the last 30 days",
    );
    expect(app.movies.canCreateMovie, isFalse);
    app.expectNoPluginChannel();
  });

  testWidgets('the picked clips land on the confirmation, titled by their '
      'count', (WidgetTester tester) async {
    final AppRobot app = await launch(tester);
    await app.journey.tapCreateMovie();
    await app.movies.tapPickVideos();

    await app.movies.tapClip(
      ClipRef(profile: _default, relPath: '2024-01-02.mp4'),
    );
    await app.movies.tapClip(
      ClipRef(profile: _default, relPath: '2024-01-04.mp4'),
    );
    await app.movies.tapPickContinue();

    expect(app.movies.confirmTitle, Strings.movieTitleHandPicked(2));
    expect(app.movies.confirmCallout, Strings.movieHandPickedNote);
    expect(app.movies.canCreateMovie, isTrue);
    app.expectNoPluginChannel();
  });
}
