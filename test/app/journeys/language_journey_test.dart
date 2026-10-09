import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_stats_bento.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

void main() {
  // Strings reads no BuildContext, so the app rebuilds every page when the
  // language changes; the profiles and the reminders follow it too.
  testWidgets('a new language shows at once on every page, with Material '
      'labels, and the pages keep their state', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(
        extra: <String, Object>{'activatedNotification': true},
      ),
    );
    await app.shell.tapTab(AppRoute.settings);
    final Element settingsTab = app.shell.pageElement(AppRoute.settings);
    await app.shell.push(AppRoute.about);
    app.shell
      ..expectPageTitle(AppRoute.about, 'About')
      ..expectBackTooltip('Back');

    await app.settings.pickLanguage(AppLanguage.de);

    app.shell
      ..expectPageTitle(AppRoute.about, 'Über die App')
      ..expectBackTooltip('Zurück');
    await app.shell.pressBack();
    app.shell
      ..expectAt(AppRoute.settings)
      ..expectPageTitle(AppRoute.settings, 'Einstellungen')
      // "Today" is Material's; diary and journey have no German translation.
      ..expectNavLabels(<String>['Heute', 'Diary', 'Journey', 'Einstellungen']);
    expect(app.shell.pageElement(AppRoute.settings), same(settingsTab));

    // Only the pick is stored.
    expect((await SharedPreferences.getInstance()).getString('lang'), 'de');
    // Default's label and the reminders follow the language.
    app.profiles.expectActiveName('Standard');
    await app.reminders.expectEveryTitle('Hallo!');
    app.expectNoPluginChannel();
  });

  testWidgets('the tabs built in English follow a new language in place: '
      "Today's weekday, the Diary's month and Journey's dates", (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: (AppPaths paths) async {
        for (final LocalDay day in <LocalDay>[
          LocalDay(2023, 12, 28),
          LocalDay(2024, 1, 4),
          LocalDay(2024, 1, 5),
        ]) {
          await seedClip(paths, ProfileKey.defaultProfile, day);
        }
      },
    );
    await app.shell.tapTab(AppRoute.diary);
    await app.shell.tapTab(AppRoute.journey);
    await app.harness.settleUntil(
      () => app.journey.hasNumber(JourneyTile.daysRecorded),
      reason: 'the diary was read',
    );
    expect(find.textContaining('December 28, 2023'), findsOneWidget);

    await app.shell.tapTab(AppRoute.settings);
    await app.settings.pickLanguage(AppLanguage.fr);

    await app.shell.tapTab(AppRoute.journey);
    expect(find.textContaining('28 décembre 2023'), findsOneWidget);
    await app.shell.tapTab(AppRoute.diary);
    expect(find.text('Janvier 2024'), findsOneWidget);
    await app.shell.tapTab(AppRoute.today);
    expect(app.today.weekday, 'VENDREDI');
  });

  testWidgets('a phone in a language the app has opens in it, and one it '
      'has not got opens in English', (WidgetTester tester) async {
    final AppRobot german = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      deviceLanguage: 'de',
    );
    // Today has no title: its weekday says the language (5 January 2024 is
    // a Friday).
    german.shell.expectPageTitle(AppRoute.today, 'FREITAG');
    await german.shell.tapTab(AppRoute.settings);
    german.shell.expectPageTitle(AppRoute.settings, 'Einstellungen');
    expect(
      (await SharedPreferences.getInstance()).containsKey('lang'),
      isFalse,
    );
  });

  testWidgets('an unsupported phone language opens in English', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      deviceLanguage: 'it',
    );

    await app.shell.tapTab(AppRoute.settings);
    app.shell.expectPageTitle(AppRoute.settings, 'Settings');
  });
}
