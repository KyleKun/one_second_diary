// ignore_for_file: file_names

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/harness/seeds.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

LocalDay jan(int day) => LocalDay(2024, 1, day);

/// A diary begun on December 30, 2023; January 3 missed, two clips on
/// January 2, nothing yet today (January 5).
Future<void> _seed(AppPaths paths) async {
  const ProfileKey profile = ProfileKey.defaultProfile;
  await seedClip(paths, profile, LocalDay(2023, 12, 30));
  await seedClip(paths, profile, jan(1));
  await seedDayClips(paths, profile, jan(2), count: 2);
  await seedClip(paths, profile, jan(4));
}

void main() {
  testWidgets('the calendar opens on this month from the diary read at '
      'launch, pages months and selects days', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: _seed,
    );

    await app.shell.tapTab(AppRoute.diary);

    app.diary
      ..expectCalendar(month: 'January 2024', count: '3 of 5 days')
      ..expectSelected(jan(4))
      ..expectNextMonthAvailable(available: false);

    await app.diary.tapDay(jan(3));
    app.diary
      ..expectSelected(jan(3))
      ..expectPanelSays('No video on Wednesday 3');

    await app.diary.showPreviousMonth();
    app.diary
      ..expectCalendar(month: 'December 2023', count: '1 of 2 days')
      ..expectSelected(LocalDay(2023, 12, 30))
      ..expectNextMonthAvailable(available: true);

    await app.diary.showNextMonth();
    app.diary.expectCalendar(month: 'January 2024', count: '3 of 5 days');
    app.expectNoPluginChannel();
  });

  testWidgets('Make movie opens M5 on the month shown', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);

    await app.diary.makeMovie();

    app.shell.expectOpenedWith(
      const CreateMovieArgs(source: MovieSource.month(year: 2024, month: 1)),
    );
  });

  testWidgets('the tab keeps its month while other tabs are used; tapping '
      'it again returns to this month', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);
    await app.diary.showPreviousMonth();

    await app.shell.tapTab(AppRoute.journey);
    await app.shell.tapTab(AppRoute.diary);
    app.diary.expectCalendar(month: 'December 2023', count: '1 of 2 days');

    await app.shell.tapTab(AppRoute.diary);
    app.diary
      ..expectCalendar(month: 'January 2024', count: '3 of 5 days')
      ..expectSelected(jan(4));
  });

  testWidgets('a clip added behind the app\'s back shows when it comes '
      'back', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);
    app.diary.expectCalendar(month: 'January 2024', count: '3 of 5 days');

    await tester.runAsync(
      () => seedClip(app.harness.paths, ProfileKey.defaultProfile, jan(3)),
    );
    // The user comes back from the Files app: the diary is read again.
    const <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);

    await app.harness.settleUntil(
      () => app.diary.countText == '4 of 5 days',
      reason: 'the new clip of January 3 counts',
    );
  });
}
