import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

void main() {
  // Today only when showIntro is false; null means onboarding.
  group('the onboarding gate', () {
    testWidgets('an onboarded v1.7 diary opens on Today', (
      WidgetTester tester,
    ) async {
      final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());

      app.shell
        ..expectAt(AppRoute.today)
        ..expectActiveTab(AppRoute.today)
        ..expectNavVisible(visible: true);
      app.expectNoPluginChannel();
    });

    testWidgets('a first launch opens onboarding', (WidgetTester tester) async {
      final AppRobot app = await AppRobot.launch(
        tester,
        prefs: freshInstallPrefs,
      );

      app.shell
        ..expectAt(AppRoute.onboarding)
        ..expectNavVisible(visible: false);
      app.expectNoPluginChannel();
    });

    testWidgets('an intro left unfinished in v1.7 opens onboarding again', (
      WidgetTester tester,
    ) async {
      final AppRobot app = await AppRobot.launch(
        tester,
        prefs: legacyPrefs(showIntro: true),
      );

      app.shell.expectAt(AppRoute.onboarding);
    });
  });

  group('the theme', () {
    testWidgets('an existing install without isDarkMode stays dark on a '
        'light phone, and nothing is stored', (WidgetTester tester) async {
      final AppRobot app = await AppRobot.launch(
        tester,
        prefs: legacyPrefs(),
        platformIsDark: false,
      );

      app.expectBrightness(Brightness.dark);
      expect(
        (await SharedPreferences.getInstance()).containsKey('isDarkMode'),
        isFalse,
      );
    });

    testWidgets('a first launch follows the phone once', (
      WidgetTester tester,
    ) async {
      final AppRobot app = await AppRobot.launch(
        tester,
        prefs: freshInstallPrefs,
        platformIsDark: false,
      );

      app.expectBrightness(Brightness.light);
      expect(
        (await SharedPreferences.getInstance()).getBool('isDarkMode'),
        isFalse,
      );
    });

    testWidgets('a stored choice wins over the phone', (
      WidgetTester tester,
    ) async {
      final AppRobot app = await AppRobot.launch(
        tester,
        prefs: legacyPrefs(extra: <String, Object>{'isDarkMode': false}),
      );

      app.expectBrightness(Brightness.light);
    });
  });

  // The profiles are read before the translations load; Default's label
  // must still come out in the app language.
  testWidgets('the Default profile is named in the app language from the '
      'start', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      deviceLanguage: 'de',
    );

    app.profiles.expectActiveName('Standard');
  });

  testWidgets('Android, access to the videos refused: the next launch asks '
      'again; allowed in the phone\'s settings, the diary shows and nothing '
      'is asked', (WidgetTester tester) async {
    final LocalDay today = LocalDay(2024, 1, 5);
    AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      isAndroid: true,
      seed: (AppPaths paths) =>
          seedClip(paths, ProfileKey.defaultProfile, today),
      configureGateways: (FakeGateways gateways) => gateways.permissions
        ..answers[AppPermission.photos] = AppPermissionStatus.denied
        ..answers[AppPermission.videos] = AppPermissionStatus.denied,
    );
    expect(
      app.harness.gateways.permissions.requestedTogether,
      <Set<AppPermission>>[
        <AppPermission>{AppPermission.photos, AppPermission.videos},
      ],
    );
    app.shell.expectAt(AppRoute.today);

    app = await app.relaunch(
      configureGateways: (FakeGateways gateways) => gateways.permissions
        ..statuses[AppPermission.photos] = AppPermissionStatus.granted
        ..statuses[AppPermission.videos] = AppPermissionStatus.granted,
    );

    expect(app.harness.gateways.permissions.requestedTogether, isEmpty);
    app.today.expectDayShows(
      ClipRef(profile: ProfileKey.defaultProfile, relPath: '2024-01-05.mp4'),
    );
    app.expectNoPluginChannel();
  });
}
