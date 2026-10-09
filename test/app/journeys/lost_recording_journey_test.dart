// On the low-memory phones that must use the system camera (Android 8–9),
// Android may kill the app while the camera is open. The recording then
// comes back through image_picker's retrieveLostData at the next launch.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/harness/settle.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

void main() {
  testWidgets('a recording Android kept opens in the clip editor, for the day '
      'it was recorded', (WidgetTester tester) async {
    late String recording;
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      isAndroid: true,
      seed: (AppPaths paths) async {
        final File file = File('${paths.temporaryDir}/REC_lost.mp4');
        await file.create(recursive: true);
        await file.writeAsBytes(fakeVideoBytes);
        await file.setLastModified(DateTime(2024, 1, 4, 23, 59));
        recording = file.path;
      },
      configureGateways: (FakeGateways gateways) => gateways.picker.lost =
          LostPick(path: recording, media: PickerMedia.video),
    );

    await app.harness.settleUntil(
      () => app.shell.location.startsWith(AppRoute.editClip.path),
      reason: 'the recovered recording opens in the clip editor',
    );

    app.shell.expectOpenedWith(
      EditClipArgs(
        source: VideoSource(
          path: recording,
          ownership: ClipOwnership.cameraTemp,
        ),
        day: LocalDay(2024, 1, 4),
        profile: ProfileKey.defaultProfile,
        recovered: true,
      ),
    );
    // Leaving it asks first and returns to Today, as after any recording.
    await app.clipEditor.pressBack();
    await app.clipEditor.tapDiscard();
    app.shell.expectAt(AppRoute.today);
    app.expectNoPluginChannel();
  });

  testWidgets('its save comes back to Today: "Video saved"', (
    WidgetTester tester,
  ) async {
    late String recording;
    late AppPaths paths;
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      isAndroid: true,
      seed: (AppPaths seeded) async {
        paths = seeded;
        final File file = File('${seeded.temporaryDir}/REC_lost.mp4');
        await file.create(recursive: true);
        await file.writeAsBytes(fakeVideoBytes);
        await file.setLastModified(DateTime(2024, 1, 5, 8));
        recording = file.path;
      },
      configureGateways: (FakeGateways gateways) {
        gateways.picker.lost = LostPick(
          path: recording,
          media: PickerMedia.video,
        );
        gateways.players.duration = const Duration(seconds: 4);
        gateways.ffmpeg.onExecute = (List<String> arguments) async {
          final File output = File(arguments[arguments.length - 2]);
          await output.parent.create(recursive: true);
          await output.writeAsBytes(const <int>[4, 2]);
        };
      },
    );
    await app.harness.settleUntil(
      () => app.shell.location.startsWith(AppRoute.editClip.path),
      reason: 'the recovered recording opens in the clip editor',
    );
    await app.clipEditor.waitForTheSource();
    // "Your last recording was recovered." shows over the save bar for 5 s.
    expect(find.text(Strings.recordingRecovered), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await settle(tester);

    await app.clipEditor.tapSave();
    await app.clipEditor.waitUntilSaved();

    app.shell.expectAt(AppRoute.today);
    await tester.pump(const Duration(milliseconds: 300));
    app.savedSnackbar.expectShown(
      subtitle: Strings.todaySnackbarSavedBodyNoName,
    );
    final File saved = File('${paths.videos}2024-01-05.mp4');
    expect(saved.existsSync(), isTrue);
    app.expectNoPluginChannel();
  });

  testWidgets('with nothing kept, the app opens on Today as usual', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      isAndroid: true,
    );

    await app.harness.settleUntil(
      () => app.harness.gateways.picker.lostPickAsked,
      reason: 'the launch asks once',
    );
    app.shell.expectAt(AppRoute.today);
  });

  testWidgets('before onboarding nothing is asked: no recording can exist', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: freshInstallPrefs,
      isAndroid: true,
    );

    app.shell.expectAt(AppRoute.onboarding);
    expect(app.harness.gateways.picker.lostPickAsked, isFalse);
  });
}
