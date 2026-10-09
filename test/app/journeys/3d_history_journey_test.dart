// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

/// Friday, March 2, 2018: a diary begun on December 30, 2017.
final DateTime _now = DateTime(2018, 3, 2, 20);

Future<void> _seed(AppPaths paths) async {
  await seedClip(paths, _default, LocalDay(2017, 12, 30));
  await seedClip(paths, _default, LocalDay(2018, 2, 10));
  await seedClip(paths, _default, LocalDay(2018, 3, 1));
}

void main() {
  testWidgets('the calendar reaches from this month back to the oldest '
      'clip\'s month, and no further either way', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      now: _now,
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);
    app.diary
      ..expectCalendar(month: 'March 2018', count: '1 of 2 days')
      ..expectNextMonthAvailable(available: false)
      ..expectPreviousMonthAvailable(available: true);

    await app.diary.showPreviousMonth();
    await app.diary.showPreviousMonth();
    app.diary
      ..expectCalendar(month: 'January 2018', count: '0 of 31 days')
      ..expectPanelSays('No videos this month');

    await app.diary.showPreviousMonth();
    app.diary
      ..expectCalendar(month: 'December 2017', count: '1 of 2 days')
      ..expectSelected(LocalDay(2017, 12, 30))
      ..expectPreviousMonthAvailable(available: false);
    app.expectNoPluginChannel();
  });

  testWidgets('the viewer\'s chevrons stop at the first and the last clip', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      now: _now,
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);

    await app.diary.expand();
    app.diary
      ..expectViewer('Thursday, March 1')
      ..expectViewerChevrons(previous: true, next: false);

    await app.diary.viewerPrevious();
    await app.diary.viewerPrevious();
    app.diary
      ..expectViewer('Saturday, December 30')
      ..expectViewerChevrons(previous: false, next: true);
  });

  testWidgets('Memories ends with the very first second', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      now: _now,
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);
    await app.diary.showMemories();

    await app.diary.scrollMemoriesToEnd();

    app.diary
      ..expectMemory(LocalDay(2017, 12, 30), title: 'Saturday 30')
      ..expectMemoriesEnd();
  });
}
