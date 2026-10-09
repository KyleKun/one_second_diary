// ignore_for_file: file_names

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_stats_bento.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/harness/seeds.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

void main() {
  /// January 3 to 5, 2024 (today), two seconds each, and one movie.
  Future<void> seedDiary(AppPaths paths) async {
    for (int day = 3; day <= 5; day++) {
      await seedClip(paths, _default, LocalDay(2024, 1, day));
    }
    await seedClipMeta(paths, <String, ClipMeta>{
      for (int day = 3; day <= 5; day++)
        '2024-01-0$day.mp4': const ClipMeta(durationMs: 2000),
    });
    await seedMovie(paths, number: 1, day: LocalDay(2024, 1, 2));
  }

  testWidgets("the Journey tab shows the diary's stats and counts every "
      'movie', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: seedDiary,
    );

    await app.shell.tapTab(AppRoute.journey);
    await app.harness.settleUntil(
      () =>
          app.journey.hasNumber(JourneyTile.daysRecorded) &&
          app.journey.hasNumber(JourneyTile.moviesMade),
      reason: 'the diary and the Movies folder were read',
    );

    expect(app.journey.numberOf(JourneyTile.daysRecorded), '3');
    app.journey
      ..expectTileSays('${Strings.journeyStreak}, ${Strings.dayCount(3)}')
      ..expectTileSays(
        '${Strings.thisMonth}, ${Strings.diaryMonthProgress(5, recorded: 3)}',
      )
      ..expectTileSays(
        '${Strings.journeyFootage}, ${Strings.journeyDurationSeconds(6)}, '
        '${Strings.clipCount(3)}',
      )
      ..expectTileSays('${Strings.myMovies}, ${Strings.journeyMovieCount(1)}');
    expect(app.journey.canCreateMovie, isTrue);
    app.expectNoPluginChannel();
    semantics.dispose();
  });

  testWidgets('Create movie opens the movie flow; My movies opens the list, '
      'and back on Journey the movies are counted again', (
    WidgetTester tester,
  ) async {
    late AppPaths seeded;
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: (AppPaths paths) async {
        seeded = paths;
        await seedDiary(paths);
      },
    );
    await app.shell.tapTab(AppRoute.journey);
    await app.harness.settleUntil(
      () => app.journey.hasNumber(JourneyTile.moviesMade),
      reason: 'the Movies folder was read',
    );

    await app.journey.tapCreateMovie();
    app.shell
      ..expectAt(AppRoute.createMovie)
      ..expectNavVisible(visible: false);
    await app.shell.pressBack();
    app.shell.expectAt(AppRoute.journey);

    await app.journey.tapMyMovies();
    app.shell.expectAt(AppRoute.myMovies);
    await tester.runAsync(
      () => seedMovie(seeded, number: 2, day: LocalDay(2024, 1, 5)),
    );
    await app.shell.pressBack();
    await app.harness.settleUntil(
      () => app.journey.numberOf(JourneyTile.moviesMade) == '2',
      reason: 'the movies were counted again',
    );
    app.expectNoPluginChannel();
  });

  testWidgets('"Days recorded" and "This month" open the Diary on this '
      'month\'s calendar; "Movies made" opens My movies; "Your life so far" '
      'opens Create movie on All time', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: (AppPaths paths) async {
        await seedDiary(paths);
        await seedClip(paths, _default, LocalDay(2023, 12, 20));
      },
    );
    await app.shell.tapTab(AppRoute.journey);
    await app.harness.settleUntil(
      () =>
          app.journey.hasNumber(JourneyTile.daysRecorded) &&
          app.journey.hasNumber(JourneyTile.moviesMade),
      reason: 'the diary and the Movies folder were read',
    );

    await app.journey.tapTile(JourneyTile.moviesMade);
    app.shell.expectAt(AppRoute.myMovies);
    await app.shell.pressBack();

    await app.journey.tapTile(JourneyTile.lifeSoFar);
    app.shell.expectAt(AppRoute.createMovie);
    expect(
      app.shell
          .pageElement(AppRoute.createMovie)
          .read<CreateMovieCubit>()
          .state
          .preset,
      MoviePreset.allTime,
    );
    await app.shell.pressBack();
    app.shell.expectAt(AppRoute.journey);

    await app.journey.tapTile(JourneyTile.daysRecorded);
    app.shell
      ..expectAt(AppRoute.diary)
      ..expectActiveTab(AppRoute.diary);

    // The tiles open this month's calendar, however the Diary was left (here
    // on December's Memories).
    await app.diary.showPreviousMonth();
    await app.diary.showMemories();
    await app.shell.tapTab(AppRoute.journey);
    await app.journey.tapTile(JourneyTile.thisMonth);
    app.shell.expectActiveTab(AppRoute.diary);
    app.diary.expectCalendar(month: 'January 2024', count: '3 of 5 days');
  });

  testWidgets('with a single clip, Create movie is off and says why', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: (AppPaths paths) => seedClip(paths, _default, LocalDay(2024, 1, 5)),
    );

    await app.shell.tapTab(AppRoute.journey);
    await app.harness.settleUntil(
      () => app.journey.hasNumber(JourneyTile.daysRecorded),
      reason: 'the diary was read',
    );

    expect(app.journey.canCreateMovie, isFalse);
    expect(app.journey.saysMoreClipsNeeded, isTrue);
  });
}
