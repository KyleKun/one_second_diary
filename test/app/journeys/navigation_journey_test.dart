import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

void main() {
  testWidgets('each tab keeps its state while the others are used, and '
      'stops its animations while hidden', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    final Element today = app.shell.pageElement(AppRoute.today);
    await app.shell.tapTab(AppRoute.journey);
    final Element journey = app.shell.pageElement(AppRoute.journey);

    await app.shell.tapTab(AppRoute.settings);
    await app.shell.push(AppRoute.preferences);
    await app.shell.pressBack();
    app.shell
      ..expectHiddenAndStill(AppRoute.today)
      ..expectHiddenAndStill(AppRoute.journey);

    await app.shell.tapTab(AppRoute.journey);
    expect(app.shell.pageElement(AppRoute.journey), same(journey));
    await app.shell.tapTab(AppRoute.today);
    expect(app.shell.pageElement(AppRoute.today), same(today));
    app.expectNoPluginChannel();
  });

  testWidgets('Android back closes the page, then returns to Today, then '
      'leaves the app', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    await app.shell.tapTab(AppRoute.journey);
    await app.shell.push(AppRoute.myMovies);

    expect(await app.shell.pressBack(), isTrue);
    app.shell
      ..expectAt(AppRoute.journey)
      ..expectNavVisible(visible: true);

    expect(await app.shell.pressBack(), isTrue);
    app.shell
      ..expectAt(AppRoute.today)
      ..expectActiveTab(AppRoute.today);

    expect(await app.shell.pressBack(), isFalse, reason: 'the app closes');
  });

  testWidgets('a screen that needs arguments is never opened without them', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    await app.shell.tapTab(AppRoute.settings);

    // A push without them is refused: the tab stays as it was.
    await expectLater(app.shell.push(AppRoute.viewer), throwsStateError);
    app.shell
      ..expectAt(AppRoute.settings)
      ..expectActiveTab(AppRoute.settings)
      ..expectOnePageOf(AppRoute.settings);

    // A location without them (a deep link) leads to a tab, shown once
    // under its own nav item.
    await app.shell.go(AppRoute.viewer);
    app.shell
      ..expectAt(AppRoute.diary)
      ..expectActiveTab(AppRoute.diary)
      ..expectOnePageOf(AppRoute.diary);

    await app.shell.go(AppRoute.editClip);
    app.shell
      ..expectAt(AppRoute.today)
      ..expectActiveTab(AppRoute.today)
      ..expectOnePageOf(AppRoute.today);
  });

  testWidgets('tapping a reminder opens Today from another tab', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    await app.shell.tapTab(AppRoute.diary);

    await app.reminders.tap(1);

    app.shell
      ..expectAt(AppRoute.today)
      ..expectNavVisible(visible: true);
  });

  // Going to Today would replace the root stack and drop a recording, an
  // unsaved edit or the movie flow without asking. The OS has already
  // brought the app to the front.
  testWidgets('tapping a reminder keeps a full-screen page open', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    await app.shell.tapTab(AppRoute.diary);
    await app.shell.open(
      RecordArgs(day: LocalDay(2024, 1, 5), profile: ProfileKey.defaultProfile),
    );

    await app.reminders.tap(1);

    app.shell.expectAt(AppRoute.record);
    expect(await app.shell.pressBack(), isTrue);
    app.shell.expectAt(AppRoute.diary);
  });

  testWidgets('before onboarding, a reminder tap keeps onboarding', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: freshInstallPrefs,
    );

    await app.reminders.tap(1);

    app.shell.expectAt(AppRoute.onboarding);
  });
}
