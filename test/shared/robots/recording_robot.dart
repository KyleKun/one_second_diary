import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/volume_key_gateway.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/recording/domain/recording_length_steps.dart';
import 'package:one_second_diary/features/recording/presentation/pages/camera_page.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_bottom_panel.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_state_overlay.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_top_bar.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_viewfinder.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/countdown_overlay.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/recording_settings_sheet.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_slider.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/surfaces/camera_state_panel.dart';

import '../fakes/fake_camera_gateway.dart';
import '../fakes/fake_picker_gateway.dart';
import '../fakes/fake_sensor_gateways.dart';
import '../harness/app_harness.dart';
import '../harness/settle.dart';
import 'shell_robot.dart';

/// The camera as the user drives it, over [AppHarness]: `app.recording`.
///
/// One method per user action, and one `expect…` per thing the user can
/// see. Journeys never read `sl`; they go through this robot.
class RecordingRobot {
  RecordingRobot(this.harness);

  final AppHarness harness;

  WidgetTester get tester => harness.tester;

  FakeCameraGateway get camera => harness.gateways.camera;

  FakeOrientationSensorGateway get orientation => harness.gateways.orientation;

  FakeVolumeKeyGateway get volumeKeys => harness.gateways.volumeKeys;

  FakePickerGateway get picker => harness.gateways.picker;

  /// Opens the camera for [args], the way Today does
  /// (`RecordArgs.push<SavedClip>`), once it is up (or explains why not).
  Future<RouteResult<SavedClip>> open(RecordArgs args) async {
    final RouteResult<SavedClip> result = await ShellRobot(
      tester,
      router: harness.router,
    ).openForResult<SavedClip>(args);
    await settle(tester);
    return result;
  }

  /// The camera's preview shows.
  void expectLive() {
    expect(camera.isOpen, isTrue, reason: 'a lens is open');
    expect(find.byKey(FakeCameraSession.previewKey), findsOneWidget);
  }

  /// The camera is released (the page left, or the app went away).
  void expectReleased() => expect(camera.isOpen, isFalse);

  /// The shutter (it records, or cancels a countdown). The clock runs from
  /// here: wait with [wait].
  Future<void> pressShutter() async {
    await tester.tap(find.byKey(CameraBottomPanel.shutterKey));
    await tester.pump();
    if (!_taking) await settle(tester);
  }

  /// The stop square, during a recording.
  Future<void> pressStop() => _tap(CameraBottomPanel.shutterKey);

  Future<void> switchLens() => _tap(CameraBottomPanel.switchKey);

  /// Close, at the top.
  Future<void> close() => _tap(CameraTopBar.closeKey);

  /// The orientation lock chip.
  Future<void> tapLock() => _tap(CameraTopBar.lockKey);

  /// The lock chip reads [label].
  void expectLock(String label) => expect(
    find.descendant(
      of: find.byKey(CameraTopBar.lockKey),
      matching: find.text(label),
    ),
    findsOneWidget,
  );

  /// The lock's explanation shows [text] (the bold word is part of it).
  void expectBubble(String text) => expect(
    find.descendant(
      of: find.byKey(CameraTopBar.bubbleKey),
      matching: find.text(text, findRichText: true),
    ),
    findsOneWidget,
  );

  /// No explanation shows.
  void expectNoBubble() =>
      expect(find.byKey(CameraTopBar.bubbleKey), findsNothing);

  /// The clip-length chip reads [label] ("2 seconds").
  void expectClipLength(String label) => expect(
    find.descendant(
      of: find.byKey(CameraBottomPanel.clipLengthKey),
      matching: find.text(label),
    ),
    findsOneWidget,
  );

  /// Tune opens the settings sheet.
  Future<void> openSettings() => _tap(CameraBottomPanel.tuneKey);

  /// The clip-length chip opens the settings sheet.
  Future<void> openSettingsFromClipLength() =>
      _tap(CameraBottomPanel.clipLengthKey);

  void expectSettingsOpen() =>
      expect(find.byType(RecordingSettingsSheet), findsOneWidget);

  void expectSettingsClosed() =>
      expect(find.byType(RecordingSettingsSheet), findsNothing);

  /// The sheet's value reads [value] ("5s").
  void expectSettingsLength(String value) => expect(
    find.descendant(
      of: find.byKey(RecordingSettingsSheet.valueKey),
      matching: find.text(value),
    ),
    findsOneWidget,
  );

  /// Taps the sheet's slider where [seconds] is (a step of
  /// `RecordingLengthSteps`, 2 to 60 s; the track is non-linear).
  Future<void> setClipLength(int seconds) async {
    final Rect track = tester.getRect(
      find.descendant(
        of: find.byKey(RecordingSettingsSheet.sliderKey),
        matching: find.byKey(OsdSlider.trackKey),
      ),
    );
    final double fraction =
        RecordingLengthSteps.indexOf(seconds) / RecordingLengthSteps.lastIndex;
    await tester.tapAt(
      Offset(track.left + track.width * fraction, track.center.dy),
    );
    await settle(tester);
  }

  /// The sheet's Countdown row.
  Future<void> toggleCountdown() => _tap(RecordingSettingsSheet.countdownKey);

  /// The sheet's Flash row.
  Future<void> toggleFlash() => _tap(RecordingSettingsSheet.flashKey);

  /// The sheet's Lock orientation row.
  Future<void> toggleLockInSettings() => _tap(RecordingSettingsSheet.lockKey);

  /// The sheet's switch rows read [countdown] and [locked].
  void expectSwitches({required bool countdown, required bool locked}) {
    bool on(Key row) => tester
        .widget<OsdSwitch>(
          find.descendant(
            of: find.byKey(row),
            matching: find.byType(OsdSwitch),
          ),
        )
        .value;
    expect(on(RecordingSettingsSheet.countdownKey), countdown);
    expect(on(RecordingSettingsSheet.lockKey), locked);
  }

  /// The sheet's Done.
  Future<void> closeSettings() => _tap(RecordingSettingsSheet.doneKey);

  /// The timer pill reads [label] ("00:01 / 00:02").
  void expectTimer(String label) => expect(
    find.descendant(
      of: find.byKey(CameraPage.timerKey),
      matching: find.text(label),
    ),
    findsOneWidget,
  );

  /// The countdown shows [numeral].
  void expectCountdown(String numeral) => expect(
    find.descendant(
      of: find.byType(CountdownOverlay),
      matching: find.text(numeral),
    ),
    findsOneWidget,
  );

  void expectNoCountdown() => expect(
    find.descendant(
      of: find.byType(CountdownOverlay),
      matching: find.byType(Text),
    ),
    findsNothing,
  );

  /// Taps the preview at [fraction] of its width and height (focus).
  Future<void> tapPreview(Offset fraction) async {
    final Rect preview = tester.getRect(
      find.byKey(CameraViewfinder.gestureKey),
    );
    await tester.tapAt(
      preview.topLeft +
          Offset(preview.width * fraction.dx, preview.height * fraction.dy),
    );
    await tester.pump();
  }

  /// Pinches the preview by [scale] (above 1: zooms in).
  Future<void> pinch(double scale) async {
    final Offset centre = tester.getCenter(
      find.byKey(CameraViewfinder.gestureKey),
    );
    const Offset half = Offset(40, 0);
    final TestGesture first = await tester.startGesture(centre - half);
    final TestGesture second = await tester.startGesture(centre + half);
    await tester.pump();
    const int steps = 5;
    for (int step = 1; step <= steps; step++) {
      final Offset spread = half * (1 + (scale - 1) * step / steps);
      await first.moveTo(centre - spread);
      await second.moveTo(centre + spread);
      await tester.pump();
    }
    await first.up();
    await second.up();
    await settle(tester);
  }

  /// The phone is held [way] (the motion sensor), long enough to count.
  Future<void> hold(DeviceOrientation way) async {
    orientation.hold(way);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
  }

  /// A volume key (Android).
  Future<void> pressVolumeKey() async {
    volumeKeys.press(VolumeKey.up);
    await tester.pump();
    await settle(tester);
  }

  /// The error panel's "Use phone's camera app".
  Future<void> tapUseSystemCamera() async {
    await tester.tap(
      find.descendant(
        of: find.byKey(CameraStateOverlay.errorKey),
        matching: find.byType(OsdTextButton),
      ),
    );
    await settle(tester);
  }

  /// Lets the camera run for [duration] (a countdown, a recording): the
  /// clock moves by exactly that much; once the take is over, what follows
  /// settles.
  Future<void> wait(Duration duration) async {
    await tester.pump(duration);
    if (!_taking) await settle(tester);
  }

  /// Whether a countdown or a recording runs (its clock and pulses never
  /// settle).
  bool get _taking =>
      camera.current?.isRecording == true ||
      find
          .descendant(
            of: find.byType(CountdownOverlay),
            matching: find.byType(Text),
          )
          .evaluate()
          .isNotEmpty;

  void expectRecording() => expect(camera.current?.isRecording, isTrue);

  /// The access panel shows [title] and its [action] ("Allow access", or
  /// "Open settings" after a permanent refusal).
  void expectAccessPanel({required String title, required String action}) =>
      _expectPanel(CameraStateOverlay.accessKey, title: title, action: action);

  /// The error panel (the camera couldn't start) shows [title] and
  /// [action].
  void expectErrorPanel({required String title, required String action}) =>
      _expectPanel(CameraStateOverlay.errorKey, title: title, action: action);

  /// Neither panel shows.
  void expectNoPanel() {
    expect(find.byKey(CameraStateOverlay.accessKey), findsNothing);
    expect(find.byKey(CameraStateOverlay.errorKey), findsNothing);
  }

  /// Taps the panel's button.
  Future<void> tapPanelAction() async {
    await tester.tap(
      find.descendant(
        of: find.byType(CameraStatePanel),
        matching: find.byType(PrimaryButton),
      ),
    );
    await settle(tester);
  }

  /// The error panel's "Report error"; waits for the mail app to open (or
  /// for the phone to say it has none).
  Future<void> tapReportError() async {
    await tester.tap(find.byKey(CameraStateOverlay.reportKey));
    await _waitForTheMailApp();
  }

  /// The snackbar's action labelled [label] ("Report error"), then what it
  /// runs.
  Future<void> tapNoticeAction(String label) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(OsdSnackbar.surfaceKey),
        matching: find.text(label),
      ),
    );
    await _waitForTheMailApp();
  }

  Future<void> _waitForTheMailApp() => harness.settleUntil(
    () =>
        harness.gateways.email.sent.isNotEmpty ||
        harness.gateways.email.mailtos.isNotEmpty,
    reason: 'the logs to be zipped and the mail app to open',
  );

  /// The user comes back to the app (from the settings, another app).
  Future<void> comeBack() async {
    <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await settle(tester);
  }

  void _expectPanel(Key key, {required String title, required String action}) {
    final Finder panel = find.byKey(key);
    expect(panel, findsOneWidget);
    expect(
      find.descendant(of: panel, matching: find.text(title)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.text(action)),
      findsOneWidget,
    );
  }

  /// The page says [title] and [body] in its snackbar.
  void expectNotice({
    required String title,
    required String body,
    String? action,
  }) {
    final Finder snackbar = find.byKey(OsdSnackbar.surfaceKey);
    expect(snackbar, findsOneWidget);
    expect(
      find.descendant(of: snackbar, matching: find.text(title)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: snackbar, matching: find.text(body)),
      findsOneWidget,
    );
    if (action != null) {
      expect(
        find.descendant(of: snackbar, matching: find.text(action)),
        findsOneWidget,
        reason: 'the notice offers $action',
      );
    }
  }

  Future<void> _tap(Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pump();
    if (!_taking) await settle(tester);
  }
}
