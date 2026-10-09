import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/permissions/access_outcome.dart';
import 'package:one_second_diary/core/permissions/permission_feature.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/platform/camera_gateway.dart';
import 'package:one_second_diary/core/platform/camera_lens.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/dual_camera_gateway.dart';
import 'package:one_second_diary/core/platform/orientation_sensor_gateway.dart';
import 'package:one_second_diary/core/platform/volume_key_gateway.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_backfill.dart';
import 'package:one_second_diary/features/clips/data/import_flow.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/import_result.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/recording/data/recording_temps.dart';
import 'package:one_second_diary/features/recording/domain/held_orientation.dart';
import 'package:one_second_diary/features/recording/domain/recording_lock.dart';
import 'package:one_second_diary/features/recording/domain/recording_timing.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

part 'recording_event.dart';
part 'recording_state.dart';

/// The in-app camera, one per camera page.
///
/// Events are handled one at a time, in order: the camera is a single
/// resource. Nothing that can wait holds that queue: the lens applies a zoom
/// in its own time, and the motion sensor is read apart ([HeldOrientation]).
class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  RecordingBloc({
    required RecordArgs args,
    required this._camera,
    required this._dualCamera,
    required this._backfill,
    required this._permissions,
    required SettingsRepository settings,
    required ProfilesRepository profiles,
    required OrientationSensorGateway orientationSensor,
    required VolumeKeyGateway volumeKeys,
    required this._import,
    required this._temps,
    required this._clock,
    required this._logger,
  }) : _args = args,
       _settings = settings,
       super(_initial(args, settings, profiles)) {
    on<RecordingEvent>(_handle, transformer: _oneAtATime);
    // The settings sheet changes these while the camera is open.
    _settingsChanges = <StreamSubscription<Object?>>[
      settings.recordingSeconds.changes.listen(_settingsChanged),
      settings.countdownBeforeRecording.changes.listen(_settingsChanged),
    ];
    _held = HeldOrientation(
      sensor: orientationSensor,
      onSettled: (DeviceOrientation orientation) =>
          add(_OrientationSettled(orientation)),
    )..listen();
    // Android only: the gateway never emits on iOS.
    _volumeKeys = volumeKeys.presses().listen(
      (VolumeKey _) => add(const _VolumeKeyPressed()),
    );
  }

  final RecordArgs _args;
  final CameraGateway _camera;

  /// The front and the back camera at once, on a phone that can.
  final DualCameraGateway _dualCamera;

  /// How many times both cameras were opened, so a failure of an earlier
  /// pair does nothing.
  int _dualOpenings = 0;

  /// The clips' metadata backfill: its probes wait while the camera is
  /// open, so they never compete with the camera's encoder.
  final ClipMetadataBackfill _backfill;
  bool _holdsBackfill = false;
  final PermissionRequester _permissions;
  final SettingsRepository _settings;
  final ImportFlow _import;
  final RecordingTemps _temps;
  final Clock _clock;
  final AppLogger _logger;

  static const String _tag = 'RECORDING';

  /// How long a lens may take to open before the page shows the error
  /// panel (a phone opens one in well under 2 s).
  static const Duration openTimeout = Duration(seconds: 10);

  CameraSession? _session;

  /// The lenses that refused their light on this page (found out by
  /// trying).
  final Set<CameraLens> _lensesWithoutLight = <CameraLens>{};

  /// The lens picked in the settings sheet, opened again when the app
  /// comes back; the camera switch forgets it.
  CameraLens? _pickedLens;

  /// The number of the page's latest recording, so a timer set for an
  /// earlier one does nothing.
  int _take = 0;
  Timer? _stopTimer;
  Timer? _countdownTimer;

  /// Whether the running recording is long enough to keep
  /// ([RecordingTiming.shortest]).
  bool _longEnough = false;
  Timer? _longEnoughTimer;

  /// Whether the app went away while recording (the page says so when the
  /// camera is back).
  bool _interrupted = false;

  /// Whether the page went away: a lens that opens now is released.
  bool _closing = false;
  late final List<StreamSubscription<Object?>> _settingsChanges;

  late final StreamSubscription<VolumeKey> _volumeKeys;

  /// How the phone is held, from the motion sensor, listened to while the
  /// app is shown.
  late final HeldOrientation _held;

  static Stream<E> _oneAtATime<E>(Stream<E> events, EventMapper<E> mapper) =>
      events.asyncExpand(mapper);

  /// The profile's format (`ProfilesRepository.formatOf`, the one source
  /// of truth) decides the canvas shape and what the lens is asked for
  /// (`CaptureQuality.of`); a profile without one
  /// records as every recording was (1080p at 30 fps).
  static RecordingState _initial(
    RecordArgs args,
    SettingsRepository settings,
    ProfilesRepository profiles,
  ) {
    final ClipFormat format = profiles.formatOf(args.profile);
    // Until the sensor says otherwise, the phone is held the profile's way.
    final DeviceOrientation held = switch (format.orientation) {
      VideoOrientation.landscape => DeviceOrientation.landscapeLeft,
      VideoOrientation.portrait => DeviceOrientation.portraitUp,
    };
    return RecordingState(
      status: RecordingStatus.opening,
      format: format,
      clipSeconds: settings.recordingSeconds.value,
      countdownEnabled: settings.countdownBeforeRecording.value,
      dualLayout: settings.dualCameraLayout.value,
      orientation: held,
      lockedOrientation: _storedLock(
        settings,
        args.profile,
        format,
      ).applyTo(held),
    );
  }

  /// The profile's lock: as toggled last, else the profile's own shape.
  static RecordingLock _storedLock(
    SettingsRepository settings,
    ProfileKey profile,
    ClipFormat format,
  ) =>
      settings.recordingLock(profile).value ??
      RecordingLock.of(format.orientation);

  /// Once the page went away ([close]), an event still waiting (a volume
  /// key pressed while the camera started) does nothing: the camera is
  /// released, and nothing may touch it again.
  Future<void> _handle(
    RecordingEvent event,
    Emitter<RecordingState> emit,
  ) async {
    if (_closing) return;
    await _react(event, emit);
  }

  Future<void> _react(RecordingEvent event, Emitter<RecordingState> emit) =>
      switch (event) {
        RecordingStarted() => _begin(emit),
        RecordingAccessRequested() => _askAgain(emit),
        RecordingSettingsOpened() => _openSettings(),
        RecordingLifecycleChanged(:final AppLifecycleState lifecycle) =>
          _lifecycleChanged(lifecycle, emit),
        RecordingRetried() => _retry(emit),
        RecordingSystemCameraRequested() => _systemCameraInstead(emit),
        RecordingLensSwitched() => _switchLens(emit),
        RecordingLensPicked(:final CameraLens lens) => _pickLens(lens, emit),
        RecordingDualToggled() => _toggleDual(emit),
        RecordingDualLayoutChanged(:final DualCameraLayout layout) =>
          _changeDualLayout(layout, emit),
        _DualFailed(:final int opening) => _dualFailed(opening, emit),
        RecordingLockToggled() => _toggleLock(emit),
        RecordingFlashToggled() => _toggleFlash(emit),
        RecordingClipSecondsChanged(:final int seconds) => _remember(
          'the clip length',
          () => _settings.recordingSeconds.set(seconds),
        ),
        RecordingCountdownToggled() => _remember(
          'the countdown',
          () => _settings.countdownBeforeRecording.set(
            !_settings.countdownBeforeRecording.value,
          ),
        ),
        RecordingZoomed(:final double level) => _zoom(level, emit),
        RecordingFocused(:final Offset point) => _focus(point, emit),
        RecordingFocusLocked(:final Offset point) => _lockFocus(point, emit),
        RecordingShutterPressed() => _shutter(emit),
        _VolumeKeyPressed() => _volumeKey(emit),
        RecordingStopPressed() => _stopEarly(emit),
        RecordingCancelled() => _cancel(emit),
        _CountdownTicked(:final int take) => _countdownTicked(take, emit),
        _RecordingTimeUp(:final int take) => _timeUp(take, emit),
        _SettingsChanged() => _readSettings(emit),
        _OrientationSettled(:final DeviceOrientation orientation) => _settle(
          orientation,
          emit,
        ),
      };

  /// The lock keeps its shape but follows the phone's side within it, so
  /// a clip is never upside down.
  Future<void> _settle(
    DeviceOrientation orientation,
    Emitter<RecordingState> emit,
  ) async {
    final DeviceOrientation? locked = state.lockedOrientation;
    emit(
      state.copyWith(
        orientation: orientation,
        lockedOrientation: () => locked == null
            ? null
            : RecordingLock.ofHeld(locked).applyTo(orientation),
      ),
    );
  }

  void _settingsChanged(Object? _) => add(const _SettingsChanged());

  Future<void> _readSettings(Emitter<RecordingState> emit) async => emit(
    state.copyWith(
      clipSeconds: _settings.recordingSeconds.value,
      countdownEnabled: _settings.countdownBeforeRecording.value,
    ),
  );

  /// Saves a setting; the state follows it through its `changes`. A
  /// setting that can't be saved keeps its value (logged).
  Future<void> _remember(String what, Future<void> Function() save) async {
    try {
      await save();
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not save $what',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Opens the lens on the other side in place of this one, and remembers
  /// it (`recordWithFrontCamera`). With both cameras open, the other one
  /// leads instead, remembered the same way.
  Future<void> _switchLens(Emitter<RecordingState> emit) async {
    if (state.status != RecordingStatus.ready || !state.canSwitchLens) return;
    final CameraFacing facing = state.lens?.facing == CameraFacing.front
        ? CameraFacing.back
        : CameraFacing.front;
    if (_session case final DualCameraSession session) {
      // Both stay open: the other camera leads.
      await session.show(primary: facing, layout: state.dualLayout);
      emit(state.copyWith(lens: session.lens));
      await _remember(
        'the lens',
        () => _settings.recordWithFrontCamera.set(facing == CameraFacing.front),
      );
      return;
    }
    _pickedLens = null;
    emit(state.copyWith(status: RecordingStatus.opening, session: () => null));
    await _release();
    await _remember(
      'the lens',
      () => _settings.recordWithFrontCamera.set(facing == CameraFacing.front),
    );
    await _open(emit, facing: facing);
  }

  /// Opens another lens of the side in use in place of this one, for this
  /// camera page only.
  Future<void> _pickLens(CameraLens lens, Emitter<RecordingState> emit) async {
    if (state.status != RecordingStatus.ready ||
        lens == state.lens ||
        !state.lensChoices.contains(lens)) {
      return;
    }
    _pickedLens = lens;
    emit(state.copyWith(status: RecordingStatus.opening, session: () => null));
    await _release();
    await _open(emit, facing: lens.facing);
  }

  /// Zooms the open lens, within its range.
  ///
  /// The lens applies it in its own time, and the shutter or a stop queued
  /// behind a pinch's zooms must never wait for it. The calls reach the camera
  /// in order, so the last one wins; a released lens ignores them.
  Future<void> _zoom(double level, Emitter<RecordingState> emit) async {
    final CameraSession? session = _session;
    if (session == null) return;
    final double zoom = level.clamp(session.minZoom, session.maxZoom);
    emit(state.copyWith(zoom: zoom));
    unawaited(session.setZoom(zoom));
  }

  /// Focuses and exposes the open lens at [point], releasing a lock.
  Future<void> _focus(Offset point, Emitter<RecordingState> emit) async {
    final CameraSession? session = _session;
    if (session == null) return;
    emit(state.copyWith(focusLocked: false));
    await session.focusAt(point);
  }

  /// Holds the focus and the exposure of the open lens at [point]; both
  /// cameras together have neither. Like a zoom, it goes on by itself so the
  /// shutter never waits for it, and the session drops it when a tap focuses
  /// meanwhile.
  Future<void> _lockFocus(Offset point, Emitter<RecordingState> emit) async {
    final CameraSession? session = _session;
    if (session == null || session is DualCameraSession) return;
    emit(state.copyWith(focusLocked: true));
    unawaited(session.lockFocusAt(point));
  }

  /// Records with both cameras, or with one again, in place of what is
  /// open, and remembers it. Both cameras record upright only, so the
  /// orientation lock goes while they are on.
  Future<void> _toggleDual(Emitter<RecordingState> emit) async {
    if (state.status != RecordingStatus.ready || !state.dualSupported) return;
    final bool dual = !state.dual;
    emit(
      state.copyWith(
        status: RecordingStatus.opening,
        dual: dual,
        lockedOrientation: () => dual
            ? null
            : _storedLock(
                _settings,
                _args.profile,
                state.format,
              ).applyTo(state.orientation),
        session: () => null,
      ),
    );
    await _release();
    await _remember('the dual camera', () => _settings.dualCamera.set(dual));
    await _open(emit);
  }

  /// Lays the two pictures out as [layout], at once when both cameras are
  /// open, and remembers it.
  Future<void> _changeDualLayout(
    DualCameraLayout layout,
    Emitter<RecordingState> emit,
  ) async {
    if (layout == state.dualLayout) return;
    emit(state.copyWith(dualLayout: layout));
    if (_session case final DualCameraSession session) {
      await session.show(primary: session.lens.facing, layout: layout);
    }
    await _remember(
      'the dual layout',
      () => _settings.dualCameraLayout.set(layout),
    );
  }

  /// Both cameras stopped working after they opened (the phone refuses the
  /// pair after all): the take, if any, is dropped, and the page records
  /// with one camera and says so.
  Future<void> _dualFailed(int opening, Emitter<RecordingState> emit) async {
    if (opening != _dualOpenings || _session is! DualCameraSession) return;
    emit(
      state.copyWith(
        status: RecordingStatus.opening,
        dual: false,
        countdown: () => null,
        session: () => null,
        notice: () => RecordingNotice.dualFailed,
      ),
    );
    await _release();
    await _open(emit);
  }

  /// Locks the recording to the shape the phone is held in now, or unlocks
  /// it, and remembers that for the profile; not during a take, and not
  /// with both cameras (they record upright).
  Future<void> _toggleLock(Emitter<RecordingState> emit) async {
    if (state.dual) return;
    if (state.status == RecordingStatus.countingDown ||
        state.status == RecordingStatus.recording) {
      return;
    }
    final DeviceOrientation? locked = state.lockedOrientation == null
        ? state.orientation
        : null;
    emit(state.copyWith(lockedOrientation: () => locked));
    await _remember(
      'the orientation lock',
      () => _settings
          .recordingLock(_args.profile)
          .set(
            locked == null ? RecordingLock.auto : RecordingLock.ofHeld(locked),
          ),
    );
  }

  /// Turns the lens's light on or off. It stays lit from here on, not only
  /// during a take, so the exposure has settled before a clip this short
  /// starts.
  Future<void> _toggleFlash(Emitter<RecordingState> emit) async {
    final CameraSession? session = _session;
    if (!state.canUseFlash || session == null) return;
    final bool on = !state.flashOn;
    emit(state.copyWith(flashOn: on));
    if (await session.setTorch(on: on)) return;
    // The lens has no light after all: the choice stays for a lens that
    // has one, and the row says this one can't.
    _lensesWithoutLight.add(session.lens);
    emit(state.copyWith(lensHasNoLight: true));
  }

  /// A volume key is the shutter while the camera is ready; it neither
  /// cancels a countdown nor stops a recording.
  Future<void> _volumeKey(Emitter<RecordingState> emit) async {
    if (state.status == RecordingStatus.ready) await _shutter(emit);
  }

  /// The shutter: records, counting down first when the countdown is on;
  /// during the countdown, cancels it.
  Future<void> _shutter(Emitter<RecordingState> emit) async {
    if (state.status == RecordingStatus.countingDown) {
      _countdownTimer?.cancel();
      emit(
        state.copyWith(status: RecordingStatus.ready, countdown: () => null),
      );
      return;
    }
    if (state.status != RecordingStatus.ready) return;
    if (!state.countdownEnabled) {
      await _record(emit);
      return;
    }
    final int take = ++_take;
    emit(
      state.copyWith(
        status: RecordingStatus.countingDown,
        countdown: () => RecordingTiming.countdownFrom,
        notice: () => null,
      ),
    );
    _countdownTimer = Timer.periodic(
      RecordingTiming.countdownStep,
      (_) => add(_CountdownTicked(take)),
    );
  }

  Future<void> _countdownTicked(int take, Emitter<RecordingState> emit) async {
    if (state.status != RecordingStatus.countingDown || take != _take) return;
    final int shown = state.countdown!;
    if (shown > 1) {
      emit(state.copyWith(countdown: () => shown - 1));
      return;
    }
    _countdownTimer?.cancel();
    await _record(emit);
  }

  /// Starts recording, and stops it once the clip length and
  /// [RecordingTiming.extra] were recorded, counted from the moment the
  /// camera started.
  Future<void> _record(Emitter<RecordingState> emit) async {
    final CameraSession session = _session!;
    final int take = ++_take;
    // A notice of the last take goes before this one is tried, so a second
    // failure in a row is said again.
    emit(state.copyWith(notice: () => null));
    // The clip is made the way the phone is held now, or the way the lock
    // keeps; turning the phone later changes nothing. Both cameras make
    // one upright picture, whatever the phone does.
    final DeviceOrientation capture = session is DualCameraSession
        ? DeviceOrientation.portraitUp
        : state.lockedOrientation ?? state.orientation;
    try {
      await session.lockCaptureOrientation(capture);
      await session.startRecording();
    } on CameraFailureException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'The camera would not start recording',
        error: error,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          status: RecordingStatus.ready,
          captureOrientation: capture,
          countdown: () => null,
          notice: () => RecordingNotice.recordFailed,
        ),
      );
      return;
    }
    // The page went away while the camera started (a start answers a few
    // hundred ms late): `close` released it, and nothing is armed.
    if (_closing) return;
    emit(
      state.copyWith(
        status: RecordingStatus.recording,
        captureOrientation: capture,
        countdown: () => null,
        notice: () => null,
      ),
    );
    _longEnough = false;
    _longEnoughTimer = Timer(
      RecordingTiming.shortest,
      () => _longEnough = true,
    );
    _stopTimer = Timer(
      RecordingTiming.captureOf(state.clipSeconds),
      () => add(_RecordingTimeUp(take)),
    );
  }

  Future<void> _timeUp(int take, Emitter<RecordingState> emit) async {
    if (take != _take) return;
    await _stop(emit);
  }

  Future<void> _stopEarly(Emitter<RecordingState> emit) => _stop(emit);

  /// Stops the recording and hands it to the clip editor, or drops it
  /// when it is shorter than [RecordingTiming.shortest].
  Future<void> _stop(Emitter<RecordingState> emit) async {
    if (state.status != RecordingStatus.recording) return;
    _stopTimer?.cancel();
    _longEnoughTimer?.cancel();
    final String path;
    try {
      path = await _session!.stopRecording();
    } on CameraFailureException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'The camera would not stop recording',
        error: error,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          status: RecordingStatus.ready,
          notice: () => RecordingNotice.recordFailed,
        ),
      );
      return;
    }
    if (!await _temps.hasData(path)) {
      // The camera wrote nothing: nothing for the editor to open.
      _logger.error(_tag, 'The camera left an empty recording at $path');
      unawaited(_temps.discard(path));
      emit(
        state.copyWith(
          status: RecordingStatus.ready,
          notice: () => RecordingNotice.recordFailed,
        ),
      );
      return;
    }
    if (!_longEnough) {
      // Never throws; the page is ready again without waiting for it.
      unawaited(_temps.discard(path));
      emit(
        state.copyWith(
          status: RecordingStatus.ready,
          notice: () => RecordingNotice.tooShort,
        ),
      );
      return;
    }
    // The editor opens on the length chosen here for a take of the app's
    // own camera; both cameras' clip opens on the last quick cut, like an
    // import.
    emit(
      state.copyWith(
        status: RecordingStatus.done,
        handOff: EditClipArgs(
          source: VideoSource(path: path, ownership: ClipOwnership.cameraTemp),
          day: _dayOfTheTake(),
          profile: _args.profile,
          mode: _args.mode,
          cameraSeconds: state.dual ? null : state.clipSeconds,
          recordedSize: state.achieved,
        ),
      ),
    );
  }

  /// The day a take that just stopped belongs to: the local date at the
  /// stop, so a take that ends after midnight is the new day's, whatever
  /// day the camera opened on. A replace keeps the day of the clip it
  /// replaces.
  LocalDay _dayOfTheTake() => switch (_args.mode) {
    AddClip() => LocalDay.fromDateTime(_clock.now()),
    ReplaceClip() => _args.day,
  };

  Future<void> _openSettings() async {
    if (state.status != RecordingStatus.needsPermission) return;
    await _permissions.openSettings();
  }

  /// The camera is released while the app is away (hidden, paused), and
  /// opened again when it is back. `inactive` alone is a passing
  /// interruption (the notification shade, a Face ID or permission prompt)
  /// and keeps it.
  Future<void> _lifecycleChanged(
    AppLifecycleState lifecycle,
    Emitter<RecordingState> emit,
  ) => switch (lifecycle) {
    AppLifecycleState.resumed => _comeBack(emit),
    AppLifecycleState.inactive => Future<void>.value(),
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => _goAway(emit),
  };

  Future<void> _goAway(Emitter<RecordingState> emit) async {
    _held.rest();
    if (_session == null) return;
    _interrupted = state.status == RecordingStatus.recording;
    // The page lets go of the preview before the camera is released.
    emit(
      state.copyWith(
        // A kept recording is still handed over.
        status: state.status == RecordingStatus.done
            ? RecordingStatus.done
            : RecordingStatus.paused,
        countdown: () => null,
        session: () => null,
      ),
    );
    await _release();
  }

  Future<void> _comeBack(Emitter<RecordingState> emit) async {
    _held.listen();
    switch (state.status) {
      case RecordingStatus.paused:
        emit(state.copyWith(status: RecordingStatus.opening));
        await _open(emit);
        if (_interrupted && state.status == RecordingStatus.ready) {
          emit(state.copyWith(notice: () => RecordingNotice.interrupted));
        }
        _interrupted = false;
      case RecordingStatus.needsPermission:
        // Back from the settings, maybe with access: check, never prompt.
        final AccessOutcome access = await _permissions.check(_feature);
        if (access != AccessOutcome.granted) {
          emit(state.copyWith(access: access));
          return;
        }
        emit(state.copyWith(access: access));
        await _startCamera(emit);
      case RecordingStatus.opening ||
          RecordingStatus.ready ||
          RecordingStatus.countingDown ||
          RecordingStatus.recording ||
          RecordingStatus.done ||
          RecordingStatus.failed ||
          RecordingStatus.usingSystemCamera ||
          RecordingStatus.cancelled:
        return;
    }
  }

  /// Back during a take: drops it, and the camera is ready again.
  Future<void> _cancel(Emitter<RecordingState> emit) async {
    if (state.status != RecordingStatus.countingDown &&
        state.status != RecordingStatus.recording) {
      return;
    }
    await _dropTake();
    emit(state.copyWith(status: RecordingStatus.ready, countdown: () => null));
  }

  /// Ends what the camera does (a countdown, a recording, whose file is
  /// deleted) and releases it.
  Future<void> _release() async {
    await _dropTake();
    final CameraSession? session = _session;
    _session = null;
    await session?.close();
  }

  /// Stops the countdown or the recording, whose file is deleted.
  Future<void> _dropTake() async {
    _countdownTimer?.cancel();
    _stopTimer?.cancel();
    _longEnoughTimer?.cancel();
    final CameraSession? session = _session;
    if (session == null || !session.isRecording) return;
    try {
      unawaited(_temps.discard(await session.stopRecording()));
    } on CameraFailureException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not stop the recording being dropped',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The page opened: the phone's camera app where it records instead of
  /// the app's (Android below 10, the "Force native camera" setting; the
  /// editor's Record again opens this page directly), else the app's camera.
  Future<void> _begin(Emitter<RecordingState> emit) async {
    if (!_holdsBackfill) {
      _holdsBackfill = true;
      _backfill.pause();
    }
    if (await _import.usesSystemCamera()) {
      emit(state.copyWith(systemCamera: true));
    } else if (await _dualCamera.isSupported()) {
      final bool dual = _settings.dualCamera.value;
      emit(
        state.copyWith(
          dualSupported: true,
          dual: dual,
          // Both cameras record upright only.
          lockedOrientation: () => dual ? null : state.lockedOrientation,
        ),
      );
    }
    await _askThenRecord(emit);
  }

  /// What the page records with needs: the camera and the microphone, or
  /// the camera alone for the phone's camera app.
  PermissionFeature get _feature => state.systemCamera
      ? PermissionFeature.nativeCameraRecording
      : PermissionFeature.recording;

  Future<void> _askAgain(Emitter<RecordingState> emit) async {
    if (state.status != RecordingStatus.needsPermission ||
        state.access != AccessOutcome.denied) {
      return;
    }
    await _askThenRecord(emit);
  }

  /// Asks for what the page needs (the system prompt shows only for what is
  /// not decided yet), then records. The app's camera records without
  /// sound when only the microphone is refused.
  Future<void> _askThenRecord(Emitter<RecordingState> emit) async {
    final AccessOutcome access = await _permissions.request(_feature);
    final bool silent =
        access != AccessOutcome.granted &&
        !state.systemCamera &&
        await _cameraAllowed();
    if (access != AccessOutcome.granted && !silent) {
      emit(
        state.copyWith(status: RecordingStatus.needsPermission, access: access),
      );
      return;
    }
    emit(state.copyWith(access: AccessOutcome.granted, microphoneOff: silent));
    await _startCamera(emit);
  }

  /// Whether the camera alone is allowed (what the phone's camera app
  /// needs), without prompting.
  Future<bool> _cameraAllowed() async =>
      await _permissions.check(PermissionFeature.nativeCameraRecording) ==
      AccessOutcome.granted;

  /// Opens the app's camera, or the phone's camera app; neither once the
  /// page went away while the system asked for access.
  Future<void> _startCamera(Emitter<RecordingState> emit) async {
    if (_closing) return;
    if (state.systemCamera) return _recordWithSystemCamera(emit);
    emit(state.copyWith(status: RecordingStatus.opening));
    await _open(emit);
  }

  Future<void> _retry(Emitter<RecordingState> emit) async {
    if (state.status != RecordingStatus.failed) return;
    await _startCamera(emit);
  }

  /// The error panel's "Use phone's camera app": once, from this page's
  /// camera, which stays on the panel when nothing comes back.
  Future<void> _systemCameraInstead(Emitter<RecordingState> emit) async {
    if (state.status != RecordingStatus.failed || state.systemCamera) return;
    await _recordWithSystemCamera(emit);
  }

  /// Records with the phone's camera app (`ImportFlow`, whose file is a
  /// camera temp) and hands its file to the clip editor. Left without a
  /// clip, a page that records with it closes; the error panel's try stays
  /// on the panel.
  Future<void> _recordWithSystemCamera(Emitter<RecordingState> emit) async {
    emit(
      state.copyWith(
        status: RecordingStatus.usingSystemCamera,
        notice: () => null,
      ),
    );
    final ImportResult result = await _import.recordWithSystemCamera();
    if (_closing) {
      // The page went away meanwhile: nobody takes the file.
      if (result case ImportPicked(:final ClipSource source)) {
        unawaited(_temps.discard(source.path));
      }
      return;
    }
    switch (result) {
      case ImportPicked(:final ClipSource source):
        emit(
          state.copyWith(
            status: RecordingStatus.done,
            handOff: EditClipArgs(
              source: source,
              day: _dayOfTheTake(),
              profile: _args.profile,
              mode: _args.mode,
            ),
          ),
        );
      case ImportCancelled():
        emit(
          state.copyWith(
            status: state.systemCamera
                ? RecordingStatus.cancelled
                : RecordingStatus.failed,
          ),
        );
      case ImportDenied():
        // The phone refused it the camera: the panel asks for it.
        final AccessOutcome access = await _permissions.check(
          PermissionFeature.nativeCameraRecording,
        );
        emit(
          state.copyWith(
            status: RecordingStatus.needsPermission,
            systemCamera: true,
            access: access == AccessOutcome.blocked
                ? AccessOutcome.blocked
                : AccessOutcome.denied,
          ),
        );
      case ImportUnavailable() || ImportRejected():
        emit(
          state.copyWith(
            status: RecordingStatus.failed,
            notice: () => RecordingNotice.recordFailed,
          ),
        );
    }
  }

  /// Opens both cameras when the page records with both ([_openDual]).
  /// Otherwise, or when they can't open, opens a lens facing [facing] (by
  /// default the side used last): the one picked in the settings sheet when it
  /// is on that side, else the first the platform lists there. Shows its
  /// preview; the error panel when the camera can't start.
  Future<void> _open(
    Emitter<RecordingState> emit, {
    CameraFacing? facing,
  }) async {
    if (state.dual && await _openDual(emit, facing: facing)) return;
    try {
      final List<CameraLens> lenses = await _camera.lenses();
      if (lenses.isEmpty) {
        throw const CameraFailureException('The phone lists no camera');
      }
      final CameraFacing wanted =
          facing ??
          (_settings.recordWithFrontCamera.value
              ? CameraFacing.front
              : CameraFacing.back);
      final CameraLens? picked = _pickedLens;
      final CameraLens lens =
          picked != null && picked.facing == wanted && lenses.contains(picked)
          ? picked
          : lenses.firstWhere(
              (CameraLens lens) => lens.facing == wanted,
              orElse: () => lenses.first,
            );
      final CameraSession session = await _openWithin(lens);
      if (_closing) {
        // The page went away while the lens opened.
        await session.close();
        return;
      }
      _session = session;
      _logAchieved(session);
      // A lens opens dark: the flash chosen on this page is lit again
      // (back from the background, or from the front lens).
      if (state.flashOn &&
          lens.facing == CameraFacing.back &&
          !_lensesWithoutLight.contains(lens) &&
          !await session.setTorch(on: true)) {
        _lensesWithoutLight.add(lens);
      }
      emit(
        state.copyWith(
          status: RecordingStatus.ready,
          lens: lens,
          achieved: () => session.achieved,
          lensHasNoLight: _lensesWithoutLight.contains(lens),
          lensChoices: <CameraLens>[
            for (final CameraLens other in lenses)
              if (other.facing == lens.facing) other,
          ],
          canSwitchLens: lenses.any(
            (CameraLens other) =>
                other.facing != lens.facing &&
                other.facing != CameraFacing.external,
          ),
          zoom: 1,
          focusLocked: false,
          // `CameraGateway.open` locks the capture to portrait.
          captureOrientation: DeviceOrientation.portraitUp,
          session: () => session,
        ),
      );
    } on CameraFailureException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'The camera could not start',
        error: error,
        stackTrace: stackTrace,
      );
      emit(state.copyWith(status: RecordingStatus.failed));
    }
  }

  /// Opens both cameras, the one facing [facing] leading (by default the
  /// side used last), and shows their one preview. False when they can't
  /// open: the page then says so and records with one camera, which the
  /// caller opens.
  Future<bool> _openDual(
    Emitter<RecordingState> emit, {
    CameraFacing? facing,
  }) async {
    final CameraFacing primary =
        facing ??
        (_settings.recordWithFrontCamera.value
            ? CameraFacing.front
            : CameraFacing.back);
    final int opening = ++_dualOpenings;
    try {
      final Future<DualCameraSession> opened = _dualCamera.open(
        primary: primary,
        layout: state.dualLayout,
        withAudio: !state.microphoneOff,
        onFailure: () {
          if (!_closing) add(_DualFailed(opening));
        },
      );
      final DualCameraSession session = await opened.timeout(
        openTimeout,
        onTimeout: () {
          opened.then((DualCameraSession late) => late.close()).ignore();
          throw const CameraFailureException(
            'Both cameras did not open in time',
          );
        },
      );
      if (_closing) {
        // The page went away while the cameras opened.
        await session.close();
        return true;
      }
      _session = session;
      _logAchieved(session);
      emit(
        state.copyWith(
          status: RecordingStatus.ready,
          lens: session.lens,
          achieved: () => session.achieved,
          lensChoices: const <CameraLens>[],
          canSwitchLens: true,
          lensHasNoLight: false,
          zoom: 1,
          focusLocked: false,
          captureOrientation: DeviceOrientation.portraitUp,
          session: () => session,
        ),
      );
      return true;
    } on CameraFailureException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Both cameras could not start',
        error: error,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(dual: false, notice: () => RecordingNotice.dualFailed),
      );
      return false;
    }
  }

  /// What the lens opened at, against what the profile asked for.
  void _logAchieved(CameraSession session) {
    final AchievedSize? achieved = session.achieved;
    final CaptureQuality asked = state.capture;
    _logger.info(
      _tag,
      'Camera preview at '
      '${achieved == null ? 'an unknown size' : '${achieved.width}×${achieved.height}'}'
      ' for ${asked.tier.token}p${asked.fps.token} (${state.format}); '
      'on Android the preview is capped near the display size and says '
      'nothing about the recording, which is probed when saved',
    );
  }

  /// Opens [lens] at the profile's quality, or fails after [openTimeout]
  /// (events wait for each other, so a plugin that never answers would
  /// hold them all). A lens that opens after all is released at once.
  Future<CameraSession> _openWithin(CameraLens lens) {
    final Future<CameraSession> opening = _camera.open(
      lens,
      withAudio: !state.microphoneOff,
      capture: state.capture,
    );
    return opening.timeout(
      openTimeout,
      onTimeout: () {
        opening.then((CameraSession late) => late.close()).ignore();
        throw const CameraFailureException('The camera did not open in time');
      },
    );
  }

  /// Releases the camera when the page goes away (nothing touches it
  /// afterwards; the session stops a recording that still runs).
  @override
  Future<void> close() async {
    _closing = true;
    // Nothing adds an event from here on.
    _held.rest();
    unawaited(_volumeKeys.cancel());
    for (final StreamSubscription<Object?> changes in _settingsChanges) {
      unawaited(changes.cancel());
    }
    await _release();
    if (_holdsBackfill) {
      _holdsBackfill = false;
      _backfill.resume();
    }
    await super.close();
  }
}
