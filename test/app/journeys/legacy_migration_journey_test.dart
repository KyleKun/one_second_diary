import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

/// A clip in the pre-2023 folder beside DCIM.
Future<void> seedPre2023Clip(AppPaths paths) async {
  final File clip = File('${paths.legacyAndroidVideos}2021-01-01.mp4');
  await clip.parent.create(recursive: true);
  await clip.writeAsBytes(fakeVideoBytes);
}

void main() {
  testWidgets('an Android diary from before 2023 is moved at launch, and the '
      'dialog says so until OK', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      isAndroid: true,
      seed: seedPre2023Clip,
    );

    app.migration.expectOutcome('Success');
    await app.migration.acknowledge();

    app.migration.expectClosed();
    app.shell.expectAt(AppRoute.today);
    expect(
      File('${app.harness.paths.videos}2021-01-01.mp4').existsSync(),
      isTrue,
    );
    app.expectNoPluginChannel();
  });

  testWidgets('no old folder, no dialog', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      isAndroid: true,
    );

    app.migration.expectClosed();
  });
}
