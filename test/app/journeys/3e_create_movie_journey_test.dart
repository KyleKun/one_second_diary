// ignore_for_file: file_names

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_stats_bento.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';

import '../../shared/harness/seeds.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

const ProfileKey _default = ProfileKey.defaultProfile;
const ProfileKey _trip = ProfileKey('Trip');
const List<ProfileSeed> _profiles = <ProfileSeed>[
  ProfileSeed('Trip', orientation: 'portrait'),
];

void main() {
  /// Default: December 2023, every day, and January 1 to 5, 2024 (today).
  /// Trip: January 2 to 4.
  Future<AppRobot> launch(WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: prefsWithProfiles(_profiles),
      seed: (AppPaths paths) async {
        for (int day = 1; day <= 31; day++) {
          await seedClip(paths, _default, LocalDay(2023, 12, day));
        }
        for (int day = 1; day <= 5; day++) {
          await seedClip(paths, _default, LocalDay(2024, 1, day));
        }
        for (int day = 2; day <= 4; day++) {
          await seedClip(paths, _trip, LocalDay(2024, 1, day));
        }
      },
    );
    await app.shell.tapTab(AppRoute.journey);
    await app.harness.settleUntil(
      () =>
          app.journey.hasNumber(JourneyTile.daysRecorded) &&
          app.shell
                  .pageElement(AppRoute.journey)
                  .read<ProfilesCubit>()
                  .state
                  .clipCountOf(_trip) !=
              null,
      reason: 'every diary was read',
    );
    return app;
  }

  /// The confirmation's "N clips, Default, landscape".
  String summaryOf(int clips) => Strings.movieSummary(
    clips: Strings.clipCount(clips),
    profile: Strings.defaultProfile,
    orientation: Strings.landscape,
  );

  testWidgets('Create movie counts the clips of "This month" at once; '
      'another range, then Continue confirms that range', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(tester);

    await app.journey.tapCreateMovie();

    app.shell.expectAt(AppRoute.createMovie);
    expect(app.movies.clipsFound, Strings.movieClipsFound(5));
    expect(app.movies.chipName, Strings.defaultProfile);

    await app.movies.tapPickVideos();
    app.shell.expectAt(AppRoute.pickClips);
    await app.shell.pressBack();
    expect(
      app.movies.clipsFound,
      Strings.movieClipsFound(5),
      reason: '"Pick videos myself" leaves the range as it was',
    );

    await app.movies.pickPreset(MoviePreset.last30Days);
    expect(app.movies.clipsFound, Strings.movieClipsFound(30));

    await app.movies.tapContinue();
    app.shell.expectAt(AppRoute.confirmMovie);
    expect(app.movies.confirmTitle, 'Dec 7, 2023 – Jan 5, 2024');
    expect(app.movies.confirmSummary, summaryOf(30));

    await app.shell.pressBack();
    await app.shell.pressBack();
    app.shell.expectAt(AppRoute.journey);
    app.expectNoPluginChannel();
  });

  testWidgets('Choose a month shows each month with its clips; last '
      "year's December makes the movie", (WidgetTester tester) async {
    final AppRobot app = await launch(tester);
    await app.journey.tapCreateMovie();

    await app.movies.tapChooseMonth();
    expect(app.movies.monthSheetShown, isTrue);
    app.movies.expectYear('2024');
    expect(app.movies.monthTile(1).count, Strings.clipCount(5));
    expect(app.movies.monthTile(1).selected, isTrue);
    expect(app.movies.monthTile(2).onTap, isNull, reason: 'the future');

    await app.movies.tapPreviousYear();
    app.movies.expectYear('2023');
    expect(app.movies.monthTile(12).count, Strings.clipCount(31));
    expect(app.movies.monthTile(12).selected, isTrue);

    await app.movies.tapMonthContinue();

    expect(app.movies.monthSheetShown, isFalse);
    app.shell.expectAt(AppRoute.confirmMovie);
    expect(app.movies.confirmTitle, 'December 2023');
    expect(app.movies.confirmSummary, summaryOf(31));
    app.expectNoPluginChannel();
  });

  // The chip offers no "Create new profile": a new profile would become the
  // app's active one, and it has no clips to make a movie of.
  testWidgets("the profile chip makes the movie of Trip's clips; the app "
      'still records into Default', (WidgetTester tester) async {
    final AppRobot app = await launch(tester);
    await app.journey.tapCreateMovie();

    await app.movies.tapProfileChip();
    app.profileSheet.expectShown(title: Strings.createMovieFromProfile);
    expect(app.profileSheet.offersCreate, isFalse);
    await app.profileSheet.tap(_trip);

    expect(app.movies.chipName, 'Trip');
    expect(app.movies.clipsFound, Strings.movieClipsFound(3));

    await app.shell.pressBack();
    await app.shell.tapTab(AppRoute.today);
    expect(app.today.profileName, Strings.defaultProfile);
  });
}
