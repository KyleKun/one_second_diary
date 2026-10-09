// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/app_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

void main() {
  /// This launch's log (the harness starts the app at 2024-01-05 10:00).
  Future<List<String>> preferenceLines(AppRobot app) async {
    final String log = (await app.tester.runAsync(() async {
      await sl<AppLogger>().flush();
      return File(
        '${app.harness.paths.logsDir}/2024-01-05_10-00-00.txt',
      ).readAsString();
    }))!;
    return <String>[
      for (final String line in log.split('\n'))
        if (line.contains('[PREFERENCES]'))
          line.substring(line.indexOf('[PREFERENCES]')),
    ];
  }

  testWidgets('a user turns every preference on or off; each is stored under '
      "v1.7's key and logged with v1.7's line", (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    await app.settings.openPreferences();

    for (final AppPreference preference in <AppPreference>[
      AppPreference.forceNativeCamera,
      AppPreference.legacyStampFont,
      AppPreference.filterByDate,
      AppPreference.alternativeCalendarColors,
      AppPreference.verboseLogging,
      AppPreference.experimentalPicker,
    ]) {
      await app.settings.togglePreference(preference);
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(
      <String, bool?>{
        for (final String key in <String>[
          'forceNativeCamera',
          'legacyStampFont',
          'useExperimentalPicker',
          'useFilterInExperimentalPicker',
          'useAlternativeCalendarColors',
          'verboseLogging',
        ])
          key: prefs.getBool(key),
      },
      <String, bool?>{
        'forceNativeCamera': true,
        'legacyStampFont': true,
        'useExperimentalPicker': false,
        // Turning the in-app picker off turned its date filter off too.
        'useFilterInExperimentalPicker': false,
        'useAlternativeCalendarColors': true,
        'verboseLogging': true,
      },
    );
    expect(await preferenceLines(app), <String>[
      '[PREFERENCES] - Force native camera for recording was enabled',
      '[PREFERENCES] - Legacy font in videos was enabled',
      '[PREFERENCES] - Use filter in experimental file picker was enabled',
      '[PREFERENCES] - Use alternative calendar colors was enabled',
      '[PREFERENCES] - Verbose logging was enabled',
      '[PREFERENCES] - Use experimental file picker was disabled',
      '[PREFERENCES] - Use filter in experimental file picker was disabled',
    ]);

    // With the in-app picker off, the date filter can't be turned on; the
    // picker back on leaves it off.
    await app.settings.togglePreference(AppPreference.filterByDate);
    expect(app.settings.preferenceOn(AppPreference.filterByDate), isFalse);
    await app.settings.togglePreference(AppPreference.experimentalPicker);
    expect(app.settings.preferenceOn(AppPreference.experimentalPicker), isTrue);
    expect(app.settings.preferenceOn(AppPreference.filterByDate), isFalse);
    expect(prefs.getBool('useFilterInExperimentalPicker'), isFalse);

    for (final AppPreference preference in <AppPreference>[
      AppPreference.forceNativeCamera,
      AppPreference.legacyStampFont,
      AppPreference.alternativeCalendarColors,
      AppPreference.verboseLogging,
    ]) {
      await app.settings.togglePreference(preference);
      expect(app.settings.preferenceOn(preference), isFalse);
    }
    expect(prefs.getBool('forceNativeCamera'), isFalse);
    expect(prefs.getBool('verboseLogging'), isFalse);
    app.expectNoPluginChannel();
  });

  testWidgets('the preferences are read back when S3 opens again', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(
        extra: <String, Object>{
          'legacyStampFont': true,
          'useExperimentalPicker': false,
          'verboseLogging': true,
        },
      ),
    );

    await app.settings.openPreferences();

    expect(
      <AppPreference, bool>{
        for (final AppPreference preference in AppPreference.values)
          preference: app.settings.preferenceOn(preference),
      },
      <AppPreference, bool>{
        AppPreference.forceNativeCamera: false,
        AppPreference.legacyStampFont: true,
        AppPreference.clipDeviceInfo: false,
        AppPreference.experimentalPicker: false,
        AppPreference.filterByDate: false,
        AppPreference.alternativeCalendarColors: false,
        AppPreference.verboseLogging: true,
      },
    );
  });

  testWidgets('on Android 9, "Force native camera" is on and stays on (the '
      'phone records with its camera app)', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      isAndroid: true,
      configureGateways: (FakeGateways gateways) =>
          gateways.deviceInfo.sdkInt = 28,
    );
    await app.settings.openPreferences();

    await app.settings.togglePreference(AppPreference.forceNativeCamera);

    expect(app.settings.preferenceOn(AppPreference.forceNativeCamera), isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool('forceNativeCamera'),
      isNull,
    );
  });
}
