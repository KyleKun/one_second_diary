// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/camera_lens.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

final LocalDay _january5 = LocalDay(2024, 1, 5);

void main() {
  testWidgets('a 2 s clip records for 3 s, then the clip editor opens on it '
      'for the day and profile asked for', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    final RecordArgs args = RecordArgs(
      day: _january5,
      profile: ProfileKey.defaultProfile,
    );

    await app.recording.open(args);
    app.recording.expectLive();
    await app.recording.pressShutter();
    app.recording.expectRecording();
    await app.recording.wait(const Duration(seconds: 3));

    app.shell
      ..expectOpenedWith(
        EditClipArgs(
          source: VideoSource(
            path: app.recording.camera.current!.recordings.single,
            ownership: ClipOwnership.cameraTemp,
          ),
          day: _january5,
          profile: ProfileKey.defaultProfile,
        ),
      )
      ..expectNoPageOf(AppRoute.record);
    app.recording.expectReleased();
    app.expectNoPluginChannel();
  });

  // A clip belongs to the local date when its recording stopped. The camera
  // opened on January 5 records January 6's second.
  testWidgets('a take that ends after midnight goes to the new day', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      now: DateTime(2024, 1, 5, 23, 59, 58),
    );
    await app.recording.open(
      RecordArgs(day: _january5, profile: ProfileKey.defaultProfile),
    );

    app.harness.clock.advance(const Duration(seconds: 10));
    await app.recording.pressShutter();
    await app.recording.wait(const Duration(seconds: 3));

    app.shell.expectOpenedWith(
      EditClipArgs(
        source: VideoSource(
          path: app.recording.camera.current!.recordings.single,
          ownership: ClipOwnership.cameraTemp,
        ),
        day: LocalDay(2024, 1, 6),
        profile: ProfileKey.defaultProfile,
      ),
    );
    app.expectNoPluginChannel();
  });

  testWidgets('stopped under half a second, nothing is kept: "Too short to '
      'save", and the camera stays for another try', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());

    await app.recording.open(
      RecordArgs(day: _january5, profile: ProfileKey.defaultProfile),
    );
    await app.recording.pressShutter();
    await app.recording.wait(const Duration(milliseconds: 300));
    await app.recording.pressStop();

    app.recording
      ..expectNotice(
        title: 'Too short to save',
        body: 'Hold on until the ring fills.',
      )
      ..expectLive();
    app.shell.expectAt(AppRoute.record);
    final File take = File(app.recording.camera.current!.recordings.single);
    await app.harness.settleUntil(
      () => !take.existsSync(),
      reason: 'the short take is deleted',
    );
  });

  testWidgets('locked upright, the clip stays upright however the phone '
      'turns while recording', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    await app.recording.open(
      RecordArgs(day: _january5, profile: ProfileKey.defaultProfile),
    );
    await app.recording.hold(DeviceOrientation.portraitUp);

    // A landscape profile starts locked landscape: off, then on as held.
    app.recording.expectLock('Locked · Landscape');
    await app.recording.tapLock();
    app.recording.expectLock('Auto-rotate');
    await app.recording.tapLock();
    app.recording.expectLock('Locked · Portrait');
    await app.recording.hold(DeviceOrientation.landscapeLeft);
    await app.recording.pressShutter();
    await app.recording.hold(DeviceOrientation.landscapeRight);

    expect(
      app.recording.camera.current!.recordedIn,
      DeviceOrientation.portraitUp,
    );
  });

  testWidgets('a 4 s clip set in R4 records for 5 s with the front lens, and '
      'the next camera opens that way', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    final RecordArgs args = RecordArgs(
      day: _january5,
      profile: ProfileKey.defaultProfile,
    );
    await app.recording.open(args);

    await app.recording.openSettings();
    await app.recording.setClipLength(4);
    await app.recording.closeSettings();
    await app.recording.switchLens();
    app.recording.expectClipLength('4 seconds');
    await app.recording.pressShutter();
    await app.recording.wait(const Duration(milliseconds: 4900));
    app.recording.expectRecording();
    await app.recording.wait(const Duration(milliseconds: 200));
    app.shell.expectNoPageOf(AppRoute.record);

    await app.recording.open(args);
    app.recording.expectClipLength('4 seconds');
    expect(app.recording.camera.current!.lens.facing, CameraFacing.front);
  });

  // The lock lasts for the camera it was set in.
  testWidgets('the next launch opens the camera with the lens, the length, '
      'the countdown and the lock as they were left', (
    WidgetTester tester,
  ) async {
    AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    final RecordArgs args = RecordArgs(
      day: _january5,
      profile: ProfileKey.defaultProfile,
    );
    await app.recording.open(args);
    await app.recording.switchLens();
    await app.recording.tapLock();
    await app.recording.openSettings();
    await app.recording.setClipLength(5);
    await app.recording.toggleCountdown();
    await app.recording.closeSettings();
    await app.recording.close();

    app = await app.relaunch();
    await app.recording.open(args);

    expect(app.recording.camera.current!.lens.facing, CameraFacing.front);
    app.recording
      ..expectClipLength('5 seconds')
      ..expectLock('Auto-rotate');
    await app.recording.pressShutter();
    app.recording.expectCountdown('3');
  });
}
