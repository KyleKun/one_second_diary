// The camera's state machine: access to the camera and the microphone, the
// lens, the countdown, the recording and its hand-over to the clip editor,
// the lifecycle.

import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/permissions/access_outcome.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/platform/camera_gateway.dart';
import 'package:one_second_diary/core/platform/camera_lens.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';
import 'package:one_second_diary/core/platform/dual_camera_gateway.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/core/platform/volume_key_gateway.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/import_flow.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/recording/domain/recording_lock.dart';
import 'package:one_second_diary/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../../../shared/fakes/fake_camera_gateway.dart';
import '../../../../shared/fakes/fake_dual_camera_gateway.dart';
import '../../../../shared/fakes/fake_picker_gateway.dart';
import '../../../../shared/fakes/fake_profiles_repository.dart';
import '../../../../shared/fakes/fake_sensor_gateways.dart';
import '../../../../support/support.dart';
import '../../../movies/support/pausable_backfill.dart';
import '../../support/gated_camera_gateway.dart';
import '../../support/instant_recording_temps.dart';
import '../../support/pending_prompt_permission_gateway.dart';
import '../../support/slow_start_camera_gateway.dart';
import '../../support/slow_zoom_camera_gateway.dart';

final LocalDay _today = LocalDay(2024, 1, 5);
final RecordArgs _args = RecordArgs(
  day: _today,
  profile: ProfileKey.defaultProfile,
);

void main() {
  late FakeCameraGateway camera;

  /// Both cameras at once: a phone that can't, unless a test says so.
  late FakeDualCameraGateway dualCamera;

  /// The clips' metadata backfill (held while the camera is open).
  late PausableBackfill backfill;
  setUp(() => backfill = PausableBackfill());

  late FakePermissionGateway permissions;
  late PrefsStore prefs;

  /// The settings the bloc of the test reads.
  late SettingsRepository settings;

  /// How the phone is held (the motion sensor).
  late FakeOrientationSensorGateway sensor;

  /// The profiles; Default is landscape.
  late FakeProfilesRepository profiles;

  /// The volume keys (Android).
  late FakeVolumeKeyGateway volumeKeys;

  /// The phone's camera app (and the other pickers).
  late FakePickerGateway picker;

  /// The Android version (34 unless a test says otherwise).
  late FakeDeviceInfoGateway deviceInfo;

  late AppPaths paths;

  /// The wall clock (the day a clip goes to is read when its take stops).
  late FakeClock clock;

  setUp(() async {
    final String dir = (await createTempRoot()).path;
    camera = FakeCameraGateway(recordingsDir: '$dir/camera');
    dualCamera = FakeDualCameraGateway(camera);
    permissions = FakePermissionGateway();
    prefs = await openLegacyPrefs(legacyPrefs());
    sensor = FakeOrientationSensorGateway();
    profiles = FakeProfilesRepository();
    volumeKeys = FakeVolumeKeyGateway();
    picker = FakePickerGateway();
    deviceInfo = FakeDeviceInfoGateway();
    paths = await createTestPaths();
    clock = FakeClock(DateTime(2024, 1, 5, 10));
  });

  tearDown(() async {
    await sensor.close();
    await volumeKeys.close();
  });

  RecordingBloc build({RecordArgs? args}) {
    settings = SettingsRepository(prefs: prefs);
    return RecordingBloc(
      args: args ?? _args,
      camera: camera,
      dualCamera: dualCamera,
      backfill: backfill,
      permissions: PermissionRequester(
        permissions: permissions,
        deviceInfo: deviceInfo,
        logger: memoryLogger(MemoryLogSink()),
      ),
      settings: settings,
      profiles: profiles,
      orientationSensor: sensor,
      volumeKeys: volumeKeys,
      import: ImportFlow(
        picker: picker,
        settings: settings,
        deviceInfo: deviceInfo,
        paths: paths,
        clock: clock,
        logger: memoryLogger(MemoryLogSink()),
        isAndroid: true,
        isIOS: false,
        firstCellLabel: ({required PickerMedia media, LocalDay? from}) => '',
      ),
      temps: InstantRecordingTemps(),
      clock: clock,
      logger: memoryLogger(MemoryLogSink()),
    );
  }

  /// Runs [body] in fake time with a bloc from [build], closed at the end.
  void run(
    void Function(FakeAsync async, RecordingBloc bloc) body, {
    RecordArgs? args,
  }) => fakeAsync((FakeAsync async) {
    final RecordingBloc bloc = build(args: args);
    body(async, bloc);
    bloc.close().ignore();
    async.flushMicrotasks();
  });

  /// [bloc] after the page opened, once the camera is up.
  void start(FakeAsync async, RecordingBloc bloc) {
    bloc.add(const RecordingStarted());
    async.flushMicrotasks();
  }

  group('opening', () {
    test('with the camera and the microphone allowed, the back lens opens '
        'and its preview shows', () {
      run((FakeAsync async, RecordingBloc bloc) {
        expect(bloc.state.status, RecordingStatus.opening);
        start(async, bloc);

        expect(permissions.requestedTogether, <Set<AppPermission>>[
          <AppPermission>{AppPermission.camera, AppPermission.microphone},
        ]);
        expect(bloc.state.status, RecordingStatus.ready);
        expect(bloc.state.lens, FakeCameraGateway.back);
        expect(bloc.state.session, same(camera.current));
        expect(camera.isOpen, isTrue);
      });
    });

    test('the lens used last opens; a phone with one lens opens it whatever '
        'was used last, and offers no switch', () async {
      prefs = await openLegacyPrefs(
        legacyPrefs(extra: <String, Object>{'recordWithFrontCamera': true}),
      );

      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);

        expect(bloc.state.lens, FakeCameraGateway.front);
        expect(camera.current!.lens, FakeCameraGateway.front);
        expect(bloc.state.canSwitchLens, isTrue);
      });

      camera.lensList = <CameraLens>[FakeCameraGateway.back];
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);

        expect(bloc.state.status, RecordingStatus.ready);
        expect(bloc.state.lens, FakeCameraGateway.back);
        expect(bloc.state.canSwitchLens, isFalse);
      });
    });

    test('a camera that can\'t start shows the error, and Try again opens '
        'it; a phone without a lens shows the error', () {
      camera.openFailure = const CameraFailureException('In use');

      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);

        expect(bloc.state.status, RecordingStatus.failed);
        expect(camera.isOpen, isFalse);

        bloc.add(const RecordingRetried());
        async.flushMicrotasks();

        expect(bloc.state.status, RecordingStatus.ready);
        expect(camera.isOpen, isTrue);
      });

      camera.lensList = <CameraLens>[];
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);

        expect(bloc.state.status, RecordingStatus.failed);
      });
    });

    // A plugin that never answers would hold every later event (they run
    // one at a time).
    test('a camera that doesn\'t answer shows the error after 10 s; one that '
        'opens after that is released at once', () async {
      final GatedCameraGateway gated = GatedCameraGateway(
        recordingsDir: camera.recordingsDir,
      );
      camera = gated;

      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        async.elapse(const Duration(milliseconds: 9999));
        expect(bloc.state.status, RecordingStatus.opening);

        async.elapse(const Duration(milliseconds: 1));
        expect(bloc.state.status, RecordingStatus.failed);

        gated.release();
        async.flushMicrotasks();
        expect(gated.sessions.single.isClosed, isTrue);
        expect(bloc.state.status, RecordingStatus.failed);

        bloc.add(const RecordingRetried());
        async.flushMicrotasks();
        expect(bloc.state.status, RecordingStatus.ready);
        expect(gated.isOpen, isTrue);
      });
    });
  });

  // The rationale loop, as state: the panel explains, and asks again or
  // opens the settings.
  group('access to the camera and the microphone', () {
    test('a refusal shows the panel that asks again; allowed then, the '
        'camera opens', () {
      permissions.answers[AppPermission.camera] = AppPermissionStatus.denied;

      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);

        expect(bloc.state.status, RecordingStatus.needsPermission);
        expect(bloc.state.access, AccessOutcome.denied);
        expect(camera.sessions, isEmpty);

        permissions.answers[AppPermission.camera] = AppPermissionStatus.granted;
        bloc.add(const RecordingAccessRequested());
        async.flushMicrotasks();

        expect(bloc.state.status, RecordingStatus.ready);
        expect(camera.isOpen, isTrue);
        expect(bloc.state.microphoneOff, isFalse);
        expect(camera.current!.withAudio, isTrue);
      });
    });

    test('without the microphone the camera still opens, without sound, and '
        'says so', () {
      permissions.answers[AppPermission.microphone] =
          AppPermissionStatus.denied;

      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);

        expect(bloc.state.status, RecordingStatus.ready);
        expect(bloc.state.microphoneOff, isTrue);
        expect(camera.current!.withAudio, isFalse);
      });
    });

    test('a permanent refusal offers the settings; back without access the '
        'panel stays and never prompts; allowed there, the camera opens', () {
      permissions.statuses[AppPermission.camera] =
          AppPermissionStatus.permanentlyDenied;

      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        final int asked = permissions.requestedTogether.length;

        expect(bloc.state.status, RecordingStatus.needsPermission);
        expect(bloc.state.access, AccessOutcome.blocked);

        bloc.add(const RecordingSettingsOpened());
        async.flushMicrotasks();
        expect(permissions.settingsOpened, isTrue);

        bloc.add(const RecordingLifecycleChanged(AppLifecycleState.resumed));
        async.flushMicrotasks();
        expect(bloc.state.status, RecordingStatus.needsPermission);
        expect(bloc.state.access, AccessOutcome.blocked);
        expect(permissions.requestedTogether, hasLength(asked));

        permissions.statuses[AppPermission.camera] =
            AppPermissionStatus.granted;
        bloc
          ..add(const RecordingLifecycleChanged(AppLifecycleState.inactive))
          ..add(const RecordingLifecycleChanged(AppLifecycleState.resumed));
        async.flushMicrotasks();

        expect(bloc.state.status, RecordingStatus.ready);
        expect(camera.isOpen, isTrue);
      });
    });
  });

  group('recording', () {
    // The camera records the clip length and 1 s more (the editor trims
    // it), counted from the moment the camera started.
    test('the shutter records the clip length and 1 s more, then hands the '
        'file to the clip editor for the day and profile asked for', () {
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        expect(bloc.state.clipSeconds, 2);

        bloc.add(const RecordingShutterPressed());
        async.flushMicrotasks();
        expect(bloc.state.status, RecordingStatus.recording);
        expect(camera.current!.isRecording, isTrue);

        async.elapse(const Duration(milliseconds: 2999));
        expect(bloc.state.status, RecordingStatus.recording);
        async.elapse(const Duration(milliseconds: 1));

        expect(camera.current!.isRecording, isFalse);
        expect(bloc.state.status, RecordingStatus.done);
        expect(
          bloc.state.handOff,
          EditClipArgs(
            source: VideoSource(
              path: camera.current!.recordings.single,
              ownership: ClipOwnership.cameraTemp,
            ),
            day: _today,
            profile: ProfileKey.defaultProfile,
            cameraSeconds: 2,
            recordedSize: (width: 1920, height: 1080),
          ),
        );
      });
    });

    // The lens is asked for the profile's tier and
    // frame rate; a profile without a format records as every recording
    // was. What the lens achieves is logged and handed to the editor.
    test('the lens opens at the profile\'s quality (legacy without a '
        'format), and the achieved size is logged and handed over; a lens '
        'that says nothing hands over nothing', () async {
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);

        expect(camera.current!.quality, CaptureQuality.legacy);
        expect(
          bloc.state.format,
          const ClipFormat.legacy(VideoOrientation.landscape),
        );
        expect(bloc.state.achieved, (width: 1920, height: 1080));
      });

      prefs = await openLegacyPrefs(
        legacyPrefs(
          extra: <String, Object>{'clipFormat_': '2160p60-hevc-stereo-sdr'},
        ),
      );
      camera.achieved = (width: 3840, height: 2160);
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);

        expect(
          camera.current!.quality,
          const CaptureQuality(tier: ResolutionTier.p2160, fps: FrameRate.f60),
        );
        expect(bloc.state.capture.tier, ResolutionTier.p2160);
        expect(bloc.state.achieved, (width: 3840, height: 2160));

        bloc.add(const RecordingShutterPressed());
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 3));
        expect(bloc.state.handOff!.recordedSize, (width: 3840, height: 2160));
        expect(bloc.state.handOff!.cameraSeconds, 2);
      });

      camera.achieved = null;
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        expect(bloc.state.achieved, isNull);

        bloc.add(const RecordingShutterPressed());
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 3));
        expect(bloc.state.handOff!.recordedSize, isNull);
      });
    });

    // A clip belongs to the local date when its recording stopped, not the
    // day the camera was opened on.
    test('a take that stops after midnight is the new day\'s clip', () {
      clock.setNow(DateTime(2024, 1, 5, 23, 59, 58));
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);

        bloc.add(const RecordingShutterPressed());
        async.flushMicrotasks();
        clock.advance(const Duration(seconds: 3));
        async.elapse(const Duration(seconds: 3));

        expect(bloc.state.status, RecordingStatus.done);
        expect(bloc.state.handOff!.day, LocalDay(2024, 1, 6));
      });
    });

    test('Record again (a replace, in another profile) hands its mode and '
        'profile to the editor, and keeps its clip\'s day past midnight', () {
      clock.setNow(DateTime(2024, 1, 6, 0, 0, 5));
      const ProfileKey trip = ProfileKey('Trip');
      final ReplaceClip replace = ReplaceClip(
        ClipRef(profile: trip, relPath: 'Profiles/Trip/${_today.fileStem}.mp4'),
      );

      run(args: RecordArgs(day: _today, profile: trip, mode: replace), (
        FakeAsync async,
        RecordingBloc bloc,
      ) {
        start(async, bloc);
        bloc.add(const RecordingShutterPressed());
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 3));

        expect(bloc.state.handOff!.mode, replace);
        expect(bloc.state.handOff!.profile, trip);
        expect(bloc.state.handOff!.day, _today);
      });
    });

    // The slider and the Countdown switch are saved at once (no Cancel) for
    // every later camera; the length keeps its 2..60 clamp,
    // and the camera records the new length and 1 s more.
    test('R4 saves the clip length (2 to 60 s) and the countdown', () {
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);

        bloc
          ..add(const RecordingClipSecondsChanged(1))
          ..add(const RecordingCountdownToggled());
        async.flushMicrotasks();
        expect(bloc.state.clipSeconds, 2);
        expect(bloc.state.countdownEnabled, isTrue);
        expect(settings.countdownBeforeRecording.value, isTrue);

        bloc
          ..add(const RecordingClipSecondsChanged(7))
          ..add(const RecordingCountdownToggled());
        async.flushMicrotasks();
        expect(settings.recordingSeconds.value, 7);
        expect(settings.countdownBeforeRecording.value, isFalse);
        expect(bloc.state.clipSeconds, 7);
        expect(bloc.state.countdownEnabled, isFalse);

        bloc.add(const RecordingShutterPressed());
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 7999));
        expect(bloc.state.status, RecordingStatus.recording);
        async.elapse(const Duration(milliseconds: 1));
        expect(bloc.state.status, RecordingStatus.done);
        expect(bloc.state.handOff!.cameraSeconds, 7);

        bloc.add(const RecordingClipSecondsChanged(90));
        async.flushMicrotasks();
        expect(bloc.state.clipSeconds, 60);
        expect(settings.recordingSeconds.value, 60);
      });
    });
  });

  // Below Android 10 the app always records with the phone's camera app, and
  // so does "Force native camera". `AddClipFlow` goes there before the camera
  // page opens; the editor's Record again opens the camera page itself, which
  // then goes there too.
  group('the phone\'s camera app', () {
    const String recorded = '/data/cache/VID_1.mp4';

    test('below Android 10 it records in the in-app camera\'s place, with '
        'the camera allowed, and its file goes to the clip editor', () {
      deviceInfo.sdkInt = 28;
      picker.cameraAnswers.add(const Picked(recorded));

      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);

        expect(permissions.requestedTogether, <Set<AppPermission>>[
          <AppPermission>{AppPermission.camera},
        ]);
        expect(picker.cameraOpened, isTrue);
        expect(camera.sessions, isEmpty, reason: 'no lens of the app opened');
        expect(bloc.state.status, RecordingStatus.done);
        expect(
          bloc.state.handOff,
          EditClipArgs(
            source: const VideoSource(
              path: recorded,
              ownership: ClipOwnership.cameraTemp,
            ),
            day: _today,
            profile: ProfileKey.defaultProfile,
          ),
        );
      });
    });

    // The day the recording stopped, as for the app's camera.
    test('a clip it brings back after midnight is the new day\'s', () {
      deviceInfo.sdkInt = 28;
      picker.cameraAnswers.add(const Picked(recorded));
      clock.setNow(DateTime(2024, 1, 6, 0, 0, 30));

      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);

        expect(bloc.state.handOff!.day, LocalDay(2024, 1, 6));
      });
    });

    test('with "Force native camera", leaving it without a clip closes the '
        'camera page', () async {
      prefs = await openLegacyPrefs(
        legacyPrefs(extra: <String, Object>{'forceNativeCamera': true}),
      );
      picker.cameraAnswers.add(const PickCancelled());

      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);

        expect(picker.cameraOpened, isTrue);
        expect(bloc.state.status, RecordingStatus.cancelled);
        expect(camera.sessions, isEmpty);
      });
    });

    test('refused the camera, the panel asks again; allowed, the phone\'s '
        'camera app opens', () {
      deviceInfo.sdkInt = 28;
      permissions.answers[AppPermission.camera] = AppPermissionStatus.denied;

      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        expect(bloc.state.status, RecordingStatus.needsPermission);
        expect(bloc.state.access, AccessOutcome.denied);
        expect(bloc.state.systemCamera, isTrue);
        expect(picker.cameraOpened, isFalse);

        permissions.answers[AppPermission.camera] = AppPermissionStatus.granted;
        picker.cameraAnswers.add(const Picked(recorded));
        bloc.add(const RecordingAccessRequested());
        async.flushMicrotasks();

        expect(bloc.state.status, RecordingStatus.done);
        expect(camera.sessions, isEmpty);
      });
    });

    test('a file it can\'t hand over shows the error panel, and Try again '
        'opens it again', () {
      deviceInfo.sdkInt = 28;
      picker.cameraAnswers.addAll(<PickerOutcome>[
        const PickUnavailable(),
        const Picked(recorded),
      ]);

      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        expect(bloc.state.status, RecordingStatus.failed);

        bloc.add(const RecordingRetried());
        async.flushMicrotasks();

        expect(bloc.state.status, RecordingStatus.done);
        expect(bloc.state.handOff!.source.path, recorded);
        expect(camera.sessions, isEmpty);
      });
    });

    // The error panel's "Use phone's camera app".
    test('when the in-app camera can\'t start, the phone\'s camera app can '
        'record instead; left without a clip, the error panel stays', () {
      camera.openFailure = const CameraFailureException('In use');
      picker.cameraAnswers.addAll(<PickerOutcome>[
        const PickCancelled(),
        const Picked(recorded),
      ]);

      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        expect(bloc.state.status, RecordingStatus.failed);
        expect(bloc.state.systemCamera, isFalse);

        bloc.add(const RecordingSystemCameraRequested());
        async.flushMicrotasks();
        expect(picker.cameraOpened, isTrue);
        expect(bloc.state.status, RecordingStatus.failed);

        bloc.add(const RecordingSystemCameraRequested());
        async.flushMicrotasks();
        expect(bloc.state.status, RecordingStatus.done);
        expect(bloc.state.handOff!.source.path, recorded);
      });
    });
  });

  // The lens is remembered (`recordWithFrontCamera`).
  test('switching lens opens the other lens in place of this one and '
      'remembers it; it does nothing while recording or with one lens', () {
    run((FakeAsync async, RecordingBloc bloc) {
      start(async, bloc);
      final FakeCameraSession back = camera.current!;

      bloc.add(const RecordingLensSwitched());
      async.flushMicrotasks();

      expect(back.isClosed, isTrue);
      expect(bloc.state.status, RecordingStatus.ready);
      expect(bloc.state.lens, FakeCameraGateway.front);
      expect(bloc.state.session, same(camera.current));
      expect(camera.current!.lens, FakeCameraGateway.front);
      expect(settings.recordWithFrontCamera.value, isTrue);

      bloc.add(const RecordingLensSwitched());
      async.flushMicrotasks();
      expect(bloc.state.lens, FakeCameraGateway.back);
      expect(settings.recordWithFrontCamera.value, isFalse);

      final CameraSession? open = bloc.state.session;
      bloc
        ..add(const RecordingShutterPressed())
        ..add(const RecordingLensSwitched());
      async.flushMicrotasks();
      expect(bloc.state.session, same(open));
      expect(bloc.state.status, RecordingStatus.recording);
    });

    camera.lensList = <CameraLens>[FakeCameraGateway.back];
    run((FakeAsync async, RecordingBloc bloc) {
      start(async, bloc);
      final CameraSession? open = bloc.state.session;

      bloc.add(const RecordingLensSwitched());
      async.flushMicrotasks();

      expect(bloc.state.session, same(open));
      expect(bloc.state.lens, FakeCameraGateway.back);
    });
  });

  // The clip is recorded the way the phone is held when recording starts,
  // unless the lock froze a way.
  group('orientation', () {
    test('the first reading is the phone\'s way at once; a change counts '
        'once the phone has stayed so for half a second (C-3); laid flat, '
        'it keeps the way it was held (C-2)', () {
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);

        sensor.hold(DeviceOrientation.portraitUp);
        async.flushMicrotasks();
        expect(bloc.state.orientation, DeviceOrientation.portraitUp);

        sensor.hold(DeviceOrientation.landscapeLeft);
        async.elapse(const Duration(milliseconds: 499));
        expect(bloc.state.orientation, DeviceOrientation.portraitUp);
        async.elapse(const Duration(milliseconds: 1));
        expect(bloc.state.orientation, DeviceOrientation.landscapeLeft);

        sensor.hold(DeviceOrientation.landscapeRight);
        async.elapse(const Duration(milliseconds: 300));
        sensor.hold(DeviceOrientation.landscapeLeft);
        async.elapse(const Duration(seconds: 1));
        expect(bloc.state.orientation, DeviceOrientation.landscapeLeft);

        sensor.hold(null);
        async.elapse(const Duration(seconds: 2));
        expect(bloc.state.orientation, DeviceOrientation.landscapeLeft);
      });
    });

    test('before the sensor says anything, the phone is held the profile\'s '
        'way', () {
      profiles = FakeProfilesRepository(
        profiles: <Profile>[
          testProfile(),
          testProfile(
            key: const ProfileKey('Travel'),
            orientation: VideoOrientation.portrait,
          ),
        ],
      );

      run(args: RecordArgs(day: _today, profile: const ProfileKey('Travel')), (
        FakeAsync async,
        RecordingBloc bloc,
      ) {
        expect(bloc.state.profileOrientation, VideoOrientation.portrait);
        expect(bloc.state.orientation, DeviceOrientation.portraitUp);
      });
      run((FakeAsync async, RecordingBloc bloc) {
        expect(bloc.state.profileOrientation, VideoOrientation.landscape);
        expect(bloc.state.orientation, DeviceOrientation.landscapeLeft);
      });
    });

    // The plugin turns an Android preview by the orientation the capture is
    // locked to, so the page turns it back; the capture stays locked after
    // a take, until a lens opens again.
    test('a recording is made the way the phone is held when it starts; the '
        'capture is portrait when a lens opens, and the recording\'s way '
        'from its start until a lens opens again', () {
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        expect(bloc.state.captureOrientation, DeviceOrientation.portraitUp);

        sensor.hold(DeviceOrientation.landscapeRight);
        async.flushMicrotasks();
        expect(bloc.state.captureOrientation, DeviceOrientation.portraitUp);
        bloc.add(const RecordingShutterPressed());
        async.flushMicrotasks();
        expect(bloc.state.captureOrientation, DeviceOrientation.landscapeRight);

        sensor.hold(DeviceOrientation.portraitUp);
        async.elapse(const Duration(seconds: 1));
        expect(camera.current!.recordedIn, DeviceOrientation.landscapeRight);
        expect(camera.current!.capture, DeviceOrientation.landscapeRight);

        bloc.add(const RecordingCancelled());
        async.flushMicrotasks();
        expect(bloc.state.captureOrientation, DeviceOrientation.landscapeRight);

        bloc.add(const RecordingLensSwitched());
        async.flushMicrotasks();
        expect(bloc.state.captureOrientation, DeviceOrientation.portraitUp);
      });
    });

    // "Lock orientation": starts as the profile's shape, follows the phone's
    // side within that shape, and is remembered per profile.
    test(
      'the camera starts locked to the profile\'s shape; the lock keeps that '
      'shape however the phone turns; unlocked, the recording follows the '
      'phone again, and the choice is remembered for the profile',
      () {
        run((FakeAsync async, RecordingBloc bloc) {
          start(async, bloc);
          expect(bloc.state.lockedOrientation, DeviceOrientation.landscapeLeft);

          sensor.hold(DeviceOrientation.landscapeRight);
          async.elapse(const Duration(seconds: 1));
          expect(
            bloc.state.lockedOrientation,
            DeviceOrientation.landscapeRight,
          );

          sensor.hold(DeviceOrientation.portraitUp);
          async.elapse(const Duration(seconds: 1));
          expect(bloc.state.orientation, DeviceOrientation.portraitUp);
          expect(
            bloc.state.lockedOrientation,
            DeviceOrientation.landscapeRight,
          );
          bloc.add(const RecordingShutterPressed());
          async
            ..flushMicrotasks()
            ..elapse(const Duration(milliseconds: 200));
          expect(camera.current!.recordedIn, DeviceOrientation.landscapeRight);

          bloc.add(const RecordingCancelled());
          bloc.add(const RecordingLockToggled());
          async.flushMicrotasks();
          expect(bloc.state.lockedOrientation, isNull);
          expect(
            settings.recordingLock(_args.profile).value,
            RecordingLock.auto,
          );
          bloc.add(const RecordingShutterPressed());
          async.flushMicrotasks();
          expect(camera.current!.recordedIn, DeviceOrientation.portraitUp);
          bloc.add(const RecordingCancelled());
          async.flushMicrotasks();

          bloc.add(const RecordingLockToggled());
          async.flushMicrotasks();
          expect(bloc.state.lockedOrientation, DeviceOrientation.portraitUp);
          expect(
            settings.recordingLock(_args.profile).value,
            RecordingLock.portrait,
          );
        });
        run((FakeAsync async, RecordingBloc bloc) {
          start(async, bloc);
          expect(bloc.state.lockedOrientation, DeviceOrientation.portraitUp);
        });
      },
    );
  });

  group('dual camera', () {
    test('is offered only on a phone that can run both cameras', () {
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        expect(bloc.state.dualSupported, isFalse);

        bloc.add(const RecordingDualToggled());
        async.flushMicrotasks();
        expect(bloc.state.dual, isFalse);
        expect(dualCamera.sessions, isEmpty);
      });
    });

    test('opens both cameras in place of one and is remembered; the camera '
        'switch makes the other one lead without opening anything; the '
        'clip is upright however the phone is held', () {
      dualCamera.supported = true;
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        expect(bloc.state.dualSupported, isTrue);
        expect(bloc.state.dual, isFalse);
        final FakeCameraSession single = camera.current!;

        bloc.add(const RecordingDualToggled());
        async.flushMicrotasks();
        expect(single.isClosed, isTrue);
        expect(settings.dualCamera.value, isTrue);
        expect(bloc.state.status, RecordingStatus.ready);
        expect(bloc.state.dual, isTrue);
        expect(bloc.state.session, same(dualCamera.current));
        expect(bloc.state.lens!.facing, CameraFacing.back);
        expect(bloc.state.canUseFlash, isFalse);

        bloc.add(const RecordingLensSwitched());
        async.flushMicrotasks();
        expect(dualCamera.sessions, hasLength(1));
        expect(dualCamera.current!.lens.facing, CameraFacing.front);
        expect(bloc.state.lens!.facing, CameraFacing.front);
        expect(settings.recordWithFrontCamera.value, isTrue);

        bloc.add(const RecordingDualLayoutChanged(DualCameraLayout.split));
        async.flushMicrotasks();
        expect(dualCamera.current!.layout, DualCameraLayout.split);
        expect(settings.dualCameraLayout.value, DualCameraLayout.split);

        // Neither the way the phone is held nor a lock turns the clip.
        sensor.hold(DeviceOrientation.landscapeLeft);
        async.elapse(const Duration(seconds: 1));
        bloc.add(const RecordingLockToggled());
        async.flushMicrotasks();
        expect(bloc.state.lockedOrientation, isNull);
        bloc.add(const RecordingShutterPressed());
        async.flushMicrotasks();
        expect(bloc.state.status, RecordingStatus.recording);
        expect(camera.current!.recordedIn, DeviceOrientation.portraitUp);
        expect(bloc.state.captureOrientation, DeviceOrientation.portraitUp);
        bloc.add(const RecordingCancelled());
        async.flushMicrotasks();

        bloc.add(const RecordingDualToggled());
        async.flushMicrotasks();
        expect(dualCamera.current!.isClosed, isTrue);
        expect(settings.dualCamera.value, isFalse);
        expect(bloc.state.dual, isFalse);
        expect(bloc.state.session, same(camera.current));
        expect(bloc.state.lens, FakeCameraGateway.front);
      });
    });

    test('remembered on, opens both cameras with the page; when they cannot '
        'open, or stop working, one camera records instead and the page '
        'says so', () {
      dualCamera.supported = true;
      run((FakeAsync async, RecordingBloc bloc) {
        settings.dualCamera.set(true).ignore();
        async.flushMicrotasks();
        dualCamera.openFailure = const CameraFailureException('busy');
        start(async, bloc);
        expect(dualCamera.sessions, isEmpty);
        expect(bloc.state.status, RecordingStatus.ready);
        expect(bloc.state.dual, isFalse);
        expect(bloc.state.notice, RecordingNotice.dualFailed);
        expect(bloc.state.session, same(camera.current));
        // The choice stays for the next camera.
        expect(settings.dualCamera.value, isTrue);

        bloc.add(const RecordingDualToggled());
        async.flushMicrotasks();
        expect(bloc.state.dual, isTrue);
        final FakeDualCameraSession pair = dualCamera.current!;

        dualCamera.fail();
        async.flushMicrotasks();
        expect(pair.isClosed, isTrue);
        expect(bloc.state.status, RecordingStatus.ready);
        expect(bloc.state.dual, isFalse);
        expect(bloc.state.notice, RecordingNotice.dualFailed);
        expect(bloc.state.session, same(camera.current));
        expect(camera.current!.isClosed, isFalse);
      });
    });
  });

  // "Lens": the other lenses of the side in use, for this camera page.
  test('a lens picked among the side\'s lenses opens in place of this one '
      'and again after the app was away; the camera switch forgets it', () {
    const CameraLens ultraWide = CameraLens(
      id: 'back-ultra-wide',
      facing: CameraFacing.back,
      sensorOrientation: 90,
      kind: CameraLensKind.ultraWide,
    );
    camera.lensList = <CameraLens>[
      FakeCameraGateway.back,
      ultraWide,
      FakeCameraGateway.front,
    ];
    run((FakeAsync async, RecordingBloc bloc) {
      start(async, bloc);
      expect(bloc.state.lens, FakeCameraGateway.back);
      expect(bloc.state.lensChoices, <CameraLens>[
        FakeCameraGateway.back,
        ultraWide,
      ]);

      // A lens of the other side is not on offer.
      bloc.add(const RecordingLensPicked(FakeCameraGateway.front));
      async.flushMicrotasks();
      expect(bloc.state.lens, FakeCameraGateway.back);

      final FakeCameraSession first = camera.current!;
      bloc.add(const RecordingLensPicked(ultraWide));
      async.flushMicrotasks();
      expect(first.isClosed, isTrue);
      expect(bloc.state.status, RecordingStatus.ready);
      expect(bloc.state.lens, ultraWide);
      expect(camera.current!.lens, ultraWide);

      bloc
        ..add(const RecordingLifecycleChanged(AppLifecycleState.paused))
        ..add(const RecordingLifecycleChanged(AppLifecycleState.resumed));
      async.flushMicrotasks();
      expect(bloc.state.lens, ultraWide);

      bloc
        ..add(const RecordingLensSwitched())
        ..add(const RecordingLensSwitched());
      async.flushMicrotasks();
      expect(bloc.state.lens, FakeCameraGateway.back);
    });
  });

  // "Flash": the back lens's light, for this camera session.
  test('the flash lights the back lens until it is turned off, is lit again '
      'on a lens that opens later, and stays off on the front lens', () {
    run((FakeAsync async, RecordingBloc bloc) {
      start(async, bloc);
      expect(bloc.state.canUseFlash, isTrue);

      bloc.add(const RecordingFlashToggled());
      async.flushMicrotasks();
      expect(bloc.state.flashOn, isTrue);
      expect(camera.current!.torch, isTrue);

      bloc.add(const RecordingLensSwitched());
      async.flushMicrotasks();
      expect(bloc.state.canUseFlash, isFalse);
      expect(camera.current!.torch, isFalse);
      // The front lens has no light: its row does nothing.
      bloc.add(const RecordingFlashToggled());
      async.flushMicrotasks();
      expect(bloc.state.flashOn, isTrue);
      expect(camera.current!.torch, isFalse);

      bloc.add(const RecordingLensSwitched());
      async.flushMicrotasks();
      expect(camera.current!.lens, FakeCameraGateway.back);
      expect(camera.current!.torch, isTrue);

      bloc.add(const RecordingFlashToggled());
      async.flushMicrotasks();
      expect(bloc.state.flashOn, isFalse);
      expect(camera.current!.torch, isFalse);
    });
  });

  // An iPhone's ultra wide or telephoto lens often has no light, and says
  // so only when asked for it.
  test('a lens that refuses its light shows the flash as unavailable, and '
      'the choice lights the next lens that has one', () {
    const CameraLens ultraWide = CameraLens(
      id: 'back-ultra-wide',
      facing: CameraFacing.back,
      sensorOrientation: 90,
      kind: CameraLensKind.ultraWide,
    );
    camera
      ..lensList = <CameraLens>[
        FakeCameraGateway.back,
        ultraWide,
        FakeCameraGateway.front,
      ]
      ..lensesWithoutTorch.add(ultraWide);
    run((FakeAsync async, RecordingBloc bloc) {
      start(async, bloc);
      bloc.add(const RecordingLensPicked(ultraWide));
      async.flushMicrotasks();
      expect(bloc.state.canUseFlash, isTrue);

      bloc.add(const RecordingFlashToggled());
      async.flushMicrotasks();
      expect(camera.current!.torch, isFalse);
      expect(bloc.state.flashOn, isTrue);
      expect(bloc.state.canUseFlash, isFalse);

      bloc.add(const RecordingLensPicked(FakeCameraGateway.back));
      async.flushMicrotasks();
      expect(bloc.state.canUseFlash, isTrue);
      expect(camera.current!.torch, isTrue);

      // Known by now: back on that lens, the row is off without a try.
      bloc.add(const RecordingLensPicked(ultraWide));
      async.flushMicrotasks();
      expect(bloc.state.canUseFlash, isFalse);
      expect(camera.current!.torch, isFalse);
    });
  });

  group('zoom and focus', () {
    test('a long press holds the focus and the exposure there until a tap '
        'focuses again or another lens opens', () {
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);

        bloc.add(const RecordingFocusLocked(Offset(.3, .6)));
        async.flushMicrotasks();
        expect(bloc.state.focusLocked, isTrue);
        expect(camera.current!.focus, const Offset(.3, .6));
        expect(camera.current!.focusLocked, isTrue);

        bloc.add(const RecordingFocused(Offset(.5, .5)));
        async.flushMicrotasks();
        expect(bloc.state.focusLocked, isFalse);
        expect(camera.current!.focusLocked, isFalse);

        bloc
          ..add(const RecordingFocusLocked(Offset(.3, .6)))
          ..add(const RecordingLensSwitched());
        async.flushMicrotasks();
        expect(bloc.state.focusLocked, isFalse);
        expect(camera.current!.focusLocked, isFalse);
      });
    });

    test('a pinch zooms within the lens\'s range, and a new lens starts '
        'unzoomed; a tap on the preview focuses and exposes there', () {
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        expect(bloc.state.zoom, 1);

        bloc.add(const RecordingZoomed(3));
        async.flushMicrotasks();
        expect(bloc.state.zoom, 3);
        expect(camera.current!.zoom, 3);

        bloc.add(const RecordingZoomed(20));
        async.flushMicrotasks();
        expect(bloc.state.zoom, 8);

        bloc.add(const RecordingFocused(Offset(.2, .7)));
        async.flushMicrotasks();
        expect(camera.current!.focus, const Offset(.2, .7));

        bloc.add(const RecordingLensSwitched());
        async.flushMicrotasks();
        expect(bloc.state.zoom, 1);
      });
    });

    // A pinch sends a zoom per frame, and a phone may take its time to
    // apply each: the shutter never waits behind them.
    test('the shutter records at once while the lens is still zooming, and '
        'the last zoom asked for is the one it ends at', () {
      final SlowZoomCameraGateway slow = SlowZoomCameraGateway(
        recordingsDir: camera.recordingsDir,
      );
      camera = slow;
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);

        bloc
          ..add(const RecordingZoomed(2))
          ..add(const RecordingZoomed(3))
          ..add(const RecordingShutterPressed());
        async.flushMicrotasks();
        expect(bloc.state.status, RecordingStatus.recording);

        slow.release();
        async.flushMicrotasks();
        expect(slow.current!.zoom, 3);
        expect(bloc.state.zoom, 3);
      });
    });
  });

  // A volume key is the shutter (Android only; the gateway never emits on
  // iOS).
  test('a volume key records like the shutter; pressed again while '
      'recording, it does nothing', () {
    run((FakeAsync async, RecordingBloc bloc) {
      start(async, bloc);

      volumeKeys.press(VolumeKey.down);
      async.flushMicrotasks();
      expect(bloc.state.status, RecordingStatus.recording);

      volumeKeys.press(VolumeKey.up);
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 1));
      expect(bloc.state.status, RecordingStatus.recording);
      async.elapse(const Duration(seconds: 2));
      expect(bloc.state.status, RecordingStatus.done);
    });
  });

  // The "Countdown" switch (the `timer` preference).
  group('the countdown', () {
    setUp(() async {
      prefs = await openLegacyPrefs(
        legacyPrefs(extra: <String, Object>{'timer': true}),
      );
    });

    test('counts 3, 2, 1 a second apart, then records', () {
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        expect(bloc.state.countdownEnabled, isTrue);

        bloc.add(const RecordingShutterPressed());
        async.flushMicrotasks();
        expect(bloc.state.status, RecordingStatus.countingDown);
        expect(bloc.state.countdown, 3);
        expect(camera.current!.isRecording, isFalse);

        async.elapse(const Duration(seconds: 1));
        expect(bloc.state.countdown, 2);
        async.elapse(const Duration(seconds: 1));
        expect(bloc.state.countdown, 1);
        async.elapse(const Duration(milliseconds: 999));
        expect(bloc.state.status, RecordingStatus.countingDown);

        async.elapse(const Duration(milliseconds: 1));
        expect(bloc.state.status, RecordingStatus.recording);
        expect(bloc.state.countdown, isNull);
        expect(camera.current!.isRecording, isTrue);

        async.elapse(const Duration(seconds: 3));
        expect(bloc.state.status, RecordingStatus.done);
      });
    });

    test('the shutter during the countdown cancels it, and the next one '
        'counts from 3 again', () {
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        bloc.add(const RecordingShutterPressed());
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 1500));
        expect(bloc.state.countdown, 2);

        bloc.add(const RecordingShutterPressed());
        async.flushMicrotasks();
        expect(bloc.state.status, RecordingStatus.ready);
        expect(bloc.state.countdown, isNull);
        async.elapse(const Duration(seconds: 5));
        expect(bloc.state.status, RecordingStatus.ready);
        expect(camera.current!.isRecording, isFalse);

        bloc.add(const RecordingShutterPressed());
        async.flushMicrotasks();
        expect(bloc.state.countdown, 3);
        async.elapse(const Duration(seconds: 3));
        expect(bloc.state.status, RecordingStatus.recording);
      });
    });
  });

  test('stopped early after half a second, what was recorded goes to the '
      'editor; before, it is dropped: "Too short to save", and the camera is '
      'ready again', () {
    run((FakeAsync async, RecordingBloc bloc) {
      start(async, bloc);
      bloc.add(const RecordingShutterPressed());
      async
        ..flushMicrotasks()
        ..elapse(const Duration(milliseconds: 499));

      bloc.add(const RecordingStopPressed());
      async.flushMicrotasks();

      expect(bloc.state.status, RecordingStatus.ready);
      expect(bloc.state.notice, RecordingNotice.tooShort);
      expect(bloc.state.handOff, isNull);
      expect(File(camera.current!.recordings.single).existsSync(), isFalse);
      expect(camera.isOpen, isTrue);

      bloc.add(const RecordingShutterPressed());
      async
        ..flushMicrotasks()
        ..elapse(const Duration(milliseconds: 500));

      bloc.add(const RecordingStopPressed());
      async.flushMicrotasks();

      expect(bloc.state.status, RecordingStatus.done);
      expect(bloc.state.handOff!.source.path, camera.current!.recordings.last);
    });
  });

  // Back during a take cancels it (a second back closes the camera).
  test('back during a take drops the recording, or stops the countdown, and '
      'the camera is ready again with nothing recording', () async {
    run((FakeAsync async, RecordingBloc bloc) {
      start(async, bloc);
      bloc.add(const RecordingShutterPressed());
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 1));

      bloc.add(const RecordingCancelled());
      async.flushMicrotasks();

      expect(bloc.state.status, RecordingStatus.ready);
      expect(bloc.state.notice, isNull);
      expect(File(camera.current!.recordings.single).existsSync(), isFalse);
      expect(camera.isOpen, isTrue);
      async.elapse(const Duration(seconds: 5));
      expect(bloc.state.status, RecordingStatus.ready);
    });

    prefs = await openLegacyPrefs(
      legacyPrefs(extra: <String, Object>{'timer': true}),
    );
    run((FakeAsync async, RecordingBloc bloc) {
      start(async, bloc);
      bloc.add(const RecordingShutterPressed());
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 1));

      bloc.add(const RecordingCancelled());
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 5));

      expect(bloc.state.status, RecordingStatus.ready);
      expect(bloc.state.countdown, isNull);
      expect(camera.current!.isRecording, isFalse);
    });
  });

  group('a recording that fails', () {
    test('a camera that won\'t start recording says so, every time, and the '
        'shutter works again', () {
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        final List<RecordingNotice?> notices = <RecordingNotice?>[];
        bloc.stream
            .map((RecordingState state) => state.notice)
            .distinct()
            .listen(notices.add);

        for (int attempt = 0; attempt < 2; attempt++) {
          camera.current!.startFailure = const CameraFailureException('Busy');
          bloc.add(const RecordingShutterPressed());
          async.flushMicrotasks();
          expect(bloc.state.status, RecordingStatus.ready);
        }
        expect(notices, <RecordingNotice?>[
          RecordingNotice.recordFailed,
          null,
          RecordingNotice.recordFailed,
        ]);

        bloc.add(const RecordingShutterPressed());
        async.flushMicrotasks();
        expect(bloc.state.status, RecordingStatus.recording);
        expect(bloc.state.notice, isNull);
      });
    });

    test('a camera that fails to stop says so and keeps nothing', () {
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        bloc.add(const RecordingShutterPressed());
        async.flushMicrotasks();
        camera.current!.stopFailure = const CameraFailureException('Lost');

        async.elapse(const Duration(seconds: 3));

        expect(bloc.state.status, RecordingStatus.ready);
        expect(bloc.state.notice, RecordingNotice.recordFailed);
        expect(bloc.state.handOff, isNull);
      });
    });
  });

  // The camera is released while the app is away and opened again when it
  // comes back.
  group('the app going away', () {
    void lifecycle(
      FakeAsync async,
      RecordingBloc bloc,
      List<AppLifecycleState> states,
    ) {
      for (final AppLifecycleState state in states) {
        bloc.add(RecordingLifecycleChanged(state));
      }
      async.flushMicrotasks();
    }

    const List<AppLifecycleState> away = <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ];
    const List<AppLifecycleState> back = <AppLifecycleState>[
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ];

    test('releases the camera and rests the motion sensor, and opens the '
        'same lens again on return', () {
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        final CameraSession? released = bloc.state.session;
        expect(sensor.listening, isTrue);

        lifecycle(async, bloc, away);
        expect(bloc.state.status, RecordingStatus.paused);
        expect(bloc.state.session, isNull);
        expect(camera.isOpen, isFalse);
        expect(sensor.listening, isFalse);

        lifecycle(async, bloc, back);
        expect(bloc.state.status, RecordingStatus.ready);
        expect(bloc.state.session, isNot(same(released)));
        expect(bloc.state.session, same(camera.current));
        expect(camera.current!.lens, FakeCameraGateway.back);
        expect(sensor.listening, isTrue);
      });
    });

    test('a passing interruption keeps the camera and the recording', () {
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        final CameraSession? recording = bloc.state.session;
        bloc.add(const RecordingShutterPressed());
        async.flushMicrotasks();

        lifecycle(async, bloc, <AppLifecycleState>[
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]);

        expect(bloc.state.status, RecordingStatus.recording);
        expect(bloc.state.session, same(recording));
        async.elapse(const Duration(seconds: 3));
        expect(bloc.state.status, RecordingStatus.done);
      });
    });

    test('while recording, the take is dropped; back, the page says '
        '"Recording stopped"; a countdown stops and nothing records on '
        'return', () async {
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        bloc.add(const RecordingShutterPressed());
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 1));
        final FakeCameraSession recorded = camera.current!;

        lifecycle(async, bloc, away);
        expect(bloc.state.status, RecordingStatus.paused);
        expect(File(recorded.recordings.single).existsSync(), isFalse);
        expect(bloc.state.notice, isNull, reason: 'said once the user is back');

        async.elapse(const Duration(seconds: 5));
        lifecycle(async, bloc, back);
        expect(bloc.state.status, RecordingStatus.ready);
        expect(bloc.state.notice, RecordingNotice.interrupted);
        expect(bloc.state.handOff, isNull);
      });

      prefs = await openLegacyPrefs(
        legacyPrefs(extra: <String, Object>{'timer': true}),
      );
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        bloc.add(const RecordingShutterPressed());
        async.flushMicrotasks();

        lifecycle(async, bloc, away);
        async.elapse(const Duration(seconds: 5));
        lifecycle(async, bloc, back);

        expect(bloc.state.status, RecordingStatus.ready);
        expect(bloc.state.countdown, isNull);
        async.elapse(const Duration(seconds: 5));
        expect(bloc.state.status, RecordingStatus.ready);
        expect(camera.current!.isRecording, isFalse);
      });
    });

    // The app may go away before the camera exists.
    test('left while the camera opens, it is released once open, and opened '
        'again on return', () {
      run((FakeAsync async, RecordingBloc bloc) {
        bloc.add(const RecordingStarted());
        lifecycle(async, bloc, away);

        expect(bloc.state.status, RecordingStatus.paused);
        expect(camera.isOpen, isFalse);

        lifecycle(async, bloc, back);
        expect(bloc.state.status, RecordingStatus.ready);
        expect(camera.isOpen, isTrue);
      });
    });

    test('a recording already kept is still handed over', () {
      run((FakeAsync async, RecordingBloc bloc) {
        start(async, bloc);
        bloc.add(const RecordingShutterPressed());
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 3));
        final EditClipArgs? handOff = bloc.state.handOff;

        lifecycle(async, bloc, away);
        lifecycle(async, bloc, back);

        expect(bloc.state.status, RecordingStatus.done);
        expect(bloc.state.handOff, handOff);
        expect(File(handOff!.source.path).existsSync(), isTrue);
      });
    });
  });

  // Closing the camera page releases the camera, on iOS and Android,
  // whatever it was doing.
  group('releasing the camera (I CL-60)', () {
    // The page may close while the system asks for access.
    test('closed while the system asks for access, no lens and no phone\'s '
        'camera app opens once allowed', () {
      for (final int sdk in <int>[34, 28]) {
        final PendingPromptPermissionGateway prompt =
            PendingPromptPermissionGateway();
        permissions = prompt;
        deviceInfo.sdkInt = sdk;

        fakeAsync((FakeAsync async) {
          final RecordingBloc bloc = build();
          start(async, bloc);

          bloc.close().ignore();
          async.flushMicrotasks();
          prompt.answer();
          async.flushMicrotasks();
        });

        expect(camera.sessions, isEmpty, reason: 'Android $sdk');
        expect(picker.cameraOpened, isFalse, reason: 'Android $sdk');
      }
    });

    // The page may close before the camera exists.
    test('closing the page while the lens opens releases it once open', () {
      final GatedCameraGateway gated = GatedCameraGateway(
        recordingsDir: camera.recordingsDir,
      );
      camera = gated;

      fakeAsync((FakeAsync async) {
        final RecordingBloc bloc = build();
        start(async, bloc);

        bloc.close().ignore();
        async.flushMicrotasks();
        gated.release();
        async.flushMicrotasks();

        expect(gated.sessions.single.isClosed, isTrue);
      });
    });

    test('closing the page releases the lens; while recording, it drops the '
        'take too, and no timer fires afterwards', () {
      fakeAsync((FakeAsync async) {
        final RecordingBloc bloc = build();
        start(async, bloc);

        bloc.close().ignore();
        async.flushMicrotasks();

        expect(camera.isOpen, isFalse);
        expect(camera.current!.isClosed, isTrue);
      });

      fakeAsync((FakeAsync async) {
        final RecordingBloc bloc = build();
        start(async, bloc);
        bloc.add(const RecordingShutterPressed());
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 1));

        bloc.close().ignore();
        async.flushMicrotasks();

        expect(camera.isOpen, isFalse);
        expect(File(camera.current!.recordings.single).existsSync(), isFalse);
        async.elapse(const Duration(seconds: 10));
        expect(async.pendingTimers, isEmpty);
      });
    });

    // The page closes while the camera is still starting (the plugin
    // answers late): the take must not go on after, and a volume key
    // pressed meanwhile does nothing.
    test('closing it while the camera starts recording releases the lens; '
        'the late start arms nothing', () {
      final SlowStartCameraGateway slow = SlowStartCameraGateway(
        recordingsDir: camera.recordingsDir,
      );
      camera = slow;

      fakeAsync((FakeAsync async) {
        final RecordingBloc bloc = build();
        start(async, bloc);
        sensor.hold(DeviceOrientation.portraitUp);
        async.flushMicrotasks();
        bloc.add(const RecordingShutterPressed());
        async.flushMicrotasks();
        expect(bloc.state.status, RecordingStatus.ready, reason: 'starting');
        // A turn and a volume key wait behind the start.
        sensor.hold(DeviceOrientation.landscapeLeft);
        volumeKeys.press(VolumeKey.down);
        async.flushMicrotasks();

        bloc.close().ignore();
        async.flushMicrotasks();
        slow.release();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 10));

        expect(slow.sessions.single.isClosed, isTrue);
        expect(slow.current!.isRecording, isFalse);
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  // The metadata backfill (an ffprobe per clip) waits while the camera
  // records, so its probes never compete with the camera's encoder.
  test('the metadata backfill waits while the camera page is open, and goes '
      'on once it closes; a page closed before it started never holds it', () {
    fakeAsync((FakeAsync async) {
      final RecordingBloc bloc = build();
      expect(backfill.paused, isFalse);

      start(async, bloc);
      expect(backfill.paused, isTrue);

      bloc.close().ignore();
      async.flushMicrotasks();
      expect(backfill.paused, isFalse);

      build().close().ignore();
      async.flushMicrotasks();
      expect(backfill.paused, isFalse);
    });
  });
}
