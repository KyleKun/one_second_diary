import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

import '../harness/app_harness.dart';
import '../harness/fake_gateways.dart';
import 'add_source_sheet_robot.dart';
import 'clip_editor_robot.dart';
import 'diary_robot.dart';
import 'journey_robot.dart';
import 'migration_robot.dart';
import 'movies_robot.dart';
import 'onboarding_robot.dart';
import 'profile_sheet_robot.dart';
import 'profiles_robot.dart';
import 'recording_robot.dart';
import 'reminders_robot.dart';
import 'saved_snackbar_robot.dart';
import 'settings_robot.dart';
import 'shell_robot.dart';
import 'subtitle_sheet_robot.dart';
import 'tags_sheet_robot.dart';
import 'today_robot.dart';

/// The app as a user drives it, over [AppHarness].
class AppRobot {
  AppRobot(this.harness)
    : shell = ShellRobot(harness.tester, router: harness.router),
      onboarding = OnboardingRobot(harness),
      today = TodayRobot(harness),
      recording = RecordingRobot(harness),
      clipEditor = ClipEditorRobot(harness),
      diary = DiaryRobot(harness),
      journey = JourneyRobot(harness),
      movies = MoviesRobot(harness),
      settings = SettingsRobot(harness),
      profiles = ProfilesRobot(harness.tester),
      reminders = RemindersRobot(harness),
      migration = MigrationRobot(harness.tester),
      savedSnackbar = SavedSnackbarRobot(harness),
      subtitleSheet = SubtitleSheetRobot(harness),
      tagsSheet = TagsSheetRobot(harness),
      addSource = AddSourceSheetRobot(harness),
      profileSheet = ProfileSheetRobot(harness);

  final AppHarness harness;

  /// The tabs, pushed routes and back (the router).
  final ShellRobot shell;

  final OnboardingRobot onboarding;
  final TodayRobot today;
  final RecordingRobot recording;
  final ClipEditorRobot clipEditor;
  final DiaryRobot diary;
  final JourneyRobot journey;
  final MoviesRobot movies;
  final SettingsRobot settings;
  final ProfilesRobot profiles;
  final RemindersRobot reminders;

  /// The folder migration's dialog.
  final MigrationRobot migration;

  /// The saved snackbar with Undo.
  final SavedSnackbarRobot savedSnackbar;

  final SubtitleSheetRobot subtitleSheet;

  /// The tags sheet, wherever it was opened from.
  final TagsSheetRobot tagsSheet;

  /// The add-source sheet (Record / Add video / Add photo).
  final AddSourceSheetRobot addSource;

  /// The profile switch sheet.
  final ProfileSheetRobot profileSheet;

  WidgetTester get tester => harness.tester;

  /// Launches the app (see [AppHarness.launch]).
  static Future<AppRobot> launch(
    WidgetTester tester, {
    required Map<String, Object> prefs,
    bool platformIsDark = true,
    String deviceLanguage = 'en',
    bool isAndroid = false,
    bool isIOS = false,
    DateTime? now,
    Future<void> Function(AppPaths paths)? seed,
    void Function(FakeGateways gateways)? configureGateways,
  }) async => AppRobot(
    await AppHarness.launch(
      tester,
      prefs: prefs,
      platformIsDark: platformIsDark,
      deviceLanguage: deviceLanguage,
      isAndroid: isAndroid,
      isIOS: isIOS,
      now: now,
      seed: seed,
      configureGateways: configureGateways,
    ),
  );

  /// The OS kills the app and the user opens it again on the same phone
  /// (see [AppHarness.relaunch]).
  Future<AppRobot> relaunch({
    void Function(FakeGateways gateways)? configureGateways,
  }) async =>
      AppRobot(await harness.relaunch(configureGateways: configureGateways));

  /// The theme the pages are drawn in.
  void expectBrightness(Brightness brightness) => expect(
    Theme.of(tester.element(find.byType(Navigator).first)).brightness,
    brightness,
  );

  /// Every message reached a Flutter framework channel (`flutter/…`): no
  /// plugin was called.
  void expectNoPluginChannel() => expect(
    harness.platformChannels.where(
      (String channel) => !channel.startsWith('flutter/'),
    ),
    isEmpty,
  );
}
