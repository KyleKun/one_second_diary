// ignore_for_file: file_names

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/onboarding/domain/onboarding_permission.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

void main() {
  testWidgets('a first launch walks the intro, picks its shape and name, '
      'allows the camera on the permissions step, and lands on Today for '
      'good', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: freshInstallPrefs,
      isAndroid: true,
    );

    app.onboarding.expectSlide(1);
    await app.onboarding.next();
    app.onboarding.expectSlide(2);
    await app.onboarding.swipeNext();
    app.onboarding.expectSlide(3);
    await app.onboarding.nextOnLastSlide();

    app.onboarding
      ..expectOrientationStep()
      ..expectContinueEnabled(enabled: false);
    await app.onboarding.pick(VideoOrientation.portrait);
    await app.onboarding.enterName('  Kyle ');
    app.onboarding.expectContinueEnabled(enabled: true);
    await app.onboarding.continueToPermissions();

    app.onboarding
      ..expectPermissionsStep()
      ..expectRowShown(OnboardingPermission.gallery)
      ..expectRowStatus(
        OnboardingPermission.camera,
        PermissionRowStatus.notAsked,
      );
    await app.onboarding.allow(OnboardingPermission.camera);
    app.onboarding.expectRowStatus(
      OnboardingPermission.camera,
      PermissionRowStatus.granted,
    );
    // The fakes answer every phone-check test at once; "Use this" takes its pick and makes the diary.
    await app.onboarding.continueToPhoneCheck();
    app.onboarding.expectPhoneCheckStep();
    await app.onboarding.useRecommended();

    app.shell
      ..expectAt(AppRoute.today)
      ..expectNavVisible(visible: true);
    app.today.expectFrameShape(VideoOrientation.portrait);
    final SharedPreferences stored = await app.harness.storedPrefs;
    expect(stored.getBool('showIntro'), isFalse);
    expect(stored.getStringList('profiles'), <String>['Default']);
    expect(stored.getString('orientation_'), 'portrait');
    // The format is the profile's, written once: a phone whose encode tests yield
    // nothing usable gets Standard.
    expect(stored.getString('clipFormat_'), '1080p30-h264-mono-sdr');
    expect(stored.getString('deviceMediaProfile'), isNotEmpty);
    expect(stored.getString('userName'), 'Kyle');
    // The first-run counters, which a downgrade reads.
    expect(stored.getInt('videoCount'), 0);
    expect(stored.getInt('movieCount'), 1);
    expect(
      app.harness.gateways.permissions.requestedTogether,
      <Set<AppPermission>>[
        <AppPermission>{AppPermission.camera},
        // The gallery row was not tapped: asked as the diary is made.
        <AppPermission>{AppPermission.photos, AppPermission.videos},
      ],
    );
    expect(
      await app.onboarding.pressBack(),
      isFalse,
      reason: 'back leaves the app: onboarding is gone',
    );
    app.expectNoPluginChannel();
  });

  // iOS asks nothing by itself: the gallery needs no permission there, and
  // every other row waits for a tap.
  testWidgets('an iPhone in light mode goes through the intro, back to it, and '
      'makes a landscape diary without a name, asking nothing when no row '
      'is tapped', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: freshInstallPrefs,
      isIOS: true,
      platformIsDark: false,
      configureGateways: (FakeGateways gateways) =>
          gateways.deviceInfo.sdkInt = null,
    );
    app.expectBrightness(Brightness.light);

    await app.onboarding.finishIntro();
    app.onboarding
      ..expectOrientationStep()
      ..expectContinueEnabled(enabled: false);
    // Back shows the intro where it was left: its last slide.
    expect(await app.onboarding.pressBack(), isTrue);
    app.onboarding.expectSlide(3);
    await app.onboarding.nextOnLastSlide();
    app.onboarding.expectOrientationStep();
    await app.onboarding.pick(VideoOrientation.landscape);
    await app.onboarding.continueToPermissions();
    app.onboarding
      ..expectPermissionsStep()
      ..expectRowShown(OnboardingPermission.gallery, shown: false)
      ..expectRowShown(OnboardingPermission.camera);
    await app.onboarding.startDiary();

    app.shell.expectAt(AppRoute.today);
    app.expectBrightness(Brightness.light);
    app.today.expectFrameShape(VideoOrientation.landscape);
    final SharedPreferences stored = await app.harness.storedPrefs;
    expect(stored.containsKey('userName'), isFalse);
    expect(stored.getString('orientation_'), 'landscape');
    expect(stored.getBool('showIntro'), isFalse);
    expect(app.harness.gateways.permissions.requested, isEmpty);
    expect(app.harness.gateways.permissions.requestedTogether, isEmpty);
    app.expectNoPluginChannel();
  });

  // An earlier install's clips keep the canvas they were made for, so the
  // orientation step never asks, and its name is not offered either: the
  // intro leads straight to the permissions step.
  testWidgets('a reinstall with clips on the phone skips O4 for the '
      'permissions step and lands on Today in landscape', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: freshInstallPrefs,
      isAndroid: true,
      seed: (AppPaths paths) =>
          seedClip(paths, ProfileKey.defaultProfile, LocalDay(2023, 12, 31)),
    );

    await app.onboarding.finishIntro();
    app.onboarding.expectPermissionsStep();
    await app.onboarding.startDiary();

    app.shell.expectAt(AppRoute.today);
    app.today.expectFrameShape(VideoOrientation.landscape);
    await app.onboarding.expectDefaultClips(1);
    final SharedPreferences stored = await app.harness.storedPrefs;
    expect(stored.getString('orientation_'), 'landscape');
    expect(stored.getBool('showIntro'), isFalse);
    expect(
      app.harness.gateways.permissions.statuses[AppPermission.videos],
      AppPermissionStatus.granted,
      reason: 'asked when the diary is made, so the old clips can be read',
    );
  });

  testWidgets('on a reinstall with the gallery refused as the diary is made, '
      '"Not now" still makes the diary', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: freshInstallPrefs,
      isAndroid: true,
      seed: (AppPaths paths) =>
          seedClip(paths, ProfileKey.defaultProfile, LocalDay(2023, 12, 31)),
      configureGateways: (FakeGateways gateways) =>
          gateways.permissions.answers[AppPermission.videos] =
              AppPermissionStatus.denied,
    );

    await app.onboarding.finishIntro();
    app.onboarding.expectPermissionsStep();
    await app.onboarding.startDiary();
    app.onboarding.expectAccessDialog();
    await app.onboarding.notNow();

    app.shell.expectAt(AppRoute.today);
    expect(
      (await app.harness.storedPrefs).getString('orientation_'),
      'landscape',
    );
  });

  testWidgets('Android: the gallery is asked for by its row, a refusal shows '
      'on the row, and "Start my diary" goes on without asking again', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: freshInstallPrefs,
      isAndroid: true,
      configureGateways: (FakeGateways gateways) =>
          gateways.permissions.answers[AppPermission.videos] =
              AppPermissionStatus.denied,
    );
    await app.onboarding.finishIntro();
    await app.onboarding.pick(VideoOrientation.landscape);
    await app.onboarding.continueToPermissions();
    expect(
      app.harness.gateways.permissions.requestedTogether,
      isEmpty,
      reason: 'nothing is asked before a tap',
    );

    await app.onboarding.allow(OnboardingPermission.gallery);
    app.onboarding.expectRowStatus(
      OnboardingPermission.gallery,
      PermissionRowStatus.denied,
    );
    app.shell.expectAt(AppRoute.onboardingPermissions);

    await app.onboarding.startDiary();

    app.shell.expectAt(AppRoute.today);
    expect(
      app.harness.gateways.permissions.requestedTogether,
      <Set<AppPermission>>[
        <AppPermission>{AppPermission.photos, AppPermission.videos},
      ],
      reason: 'asked once, by the row',
    );
  });

  testWidgets('killed on O4 before "Continue", the relaunch starts over at '
      'O1 with nothing kept', (WidgetTester tester) async {
    AppRobot app = await AppRobot.launch(
      tester,
      prefs: freshInstallPrefs,
      isAndroid: true,
    );
    await app.onboarding.finishIntro();
    await app.onboarding.pick(VideoOrientation.portrait);
    await app.onboarding.enterName('Kyle');

    app = await app.relaunch();

    app.onboarding.expectSlide(1);
    await app.onboarding.finishIntro();
    app.onboarding
      ..expectOrientationStep()
      ..expectContinueEnabled(enabled: false)
      ..expectName('');
    await app.onboarding.pick(VideoOrientation.landscape);
    await app.onboarding.startDiary();

    app.shell.expectAt(AppRoute.today);
    app.today.expectFrameShape(VideoOrientation.landscape);
  });

  // showIntro is written last: a kill after the canvas was stored relaunches
  // into onboarding, which finishes with that canvas and never asks again.
  testWidgets('a relaunch after a kill before the end finishes with the '
      'shape already stored, without O4', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(
        showIntro: null,
        selectedProfileIndex: null,
        orientations: <String, String>{'': 'portrait'},
        videoCount: null,
        movieCount: null,
      ),
    );
    app.onboarding.expectSlide(1);

    await app.onboarding.finishIntro();
    app.onboarding.expectPermissionsStep();
    await app.onboarding.startDiary();

    app.shell.expectAt(AppRoute.today);
    final SharedPreferences stored = await app.harness.storedPrefs;
    expect(stored.getString('orientation_'), 'portrait');
    expect(stored.getBool('showIntro'), isFalse);
  });
}
