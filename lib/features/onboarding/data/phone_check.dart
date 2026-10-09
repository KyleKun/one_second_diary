import 'dart:async';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/permissions/access_outcome.dart';
import 'package:one_second_diary/core/permissions/permission_feature.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/free_space_gateway.dart';
import 'package:one_second_diary/core/storage/storage_budget.dart';
import 'package:one_second_diary/features/onboarding/domain/camera_capability_probe.dart';
import 'package:one_second_diary/features/onboarding/domain/device_media_check_runner.dart';
import 'package:one_second_diary/features/onboarding/domain/phone_check_progress.dart';
import 'package:one_second_diary/features/profiles/data/device_media_profile_store.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';

/// A phone check in flight: its progress, its result, and cancel.
final class PhoneCheckRun {
  PhoneCheckRun._();

  // Closed by the check when the run ends (`PhoneCheck._end`).
  // ignore: close_sinks
  final StreamController<PhoneCheckProgress> _progress =
      StreamController<PhoneCheckProgress>.broadcast();
  final Completer<DeviceMediaProfile?> _result =
      Completer<DeviceMediaProfile?>();
  DeviceMediaCheckRun? _media;
  bool _cancelled = false;

  /// Each test as it starts.
  Stream<PhoneCheckProgress> get progress => _progress.stream;

  /// The stored profile once every test ran; null when cancelled or when
  /// the check could not run (logged).
  Future<DeviceMediaProfile?> get result => _result.future;

  bool get isCancelled => _cancelled;

  /// Stops after the test in flight; [result] completes with null.
  Future<void> cancel() async {
    _cancelled = true;
    await _media?.cancel();
  }
}

/// The phone check : the storage budget first
/// (its synthetic encodes need a few MB, `StorageBudget.phoneCheckBytes`;
/// a full phone gets no check), then the media tests over the engine
/// ([DeviceMediaCheckRunner]), the camera probe (only with the camera
/// permission; without it the camera is unknown and the recommendation
/// stays at 1080p), the free space, stamped with the clock, the app
/// version and the phone, and stored.
///
/// A plain class (not final), so cubit tests can fake it.
class PhoneCheck {
  PhoneCheck({
    required this._runner,
    required this._camera,
    required this._freeSpace,
    required this._permissions,
    required this._store,
    required this._clock,
    required this._logger,
  });

  final DeviceMediaCheckRunner _runner;
  final CameraCapabilityProbe _camera;
  final FreeSpaceGateway _freeSpace;
  final PermissionRequester _permissions;
  final DeviceMediaProfileStore _store;
  final Clock _clock;
  final AppLogger _logger;

  static const String _tag = 'PHONE_CHECK';

  /// The tests after the media ones: the camera and the free space.
  static const int extraSteps = 2;

  /// Starts a check. The run outlives its caller: a cancelled run stores
  /// nothing, a finished one stores its profile even when nobody waits
  /// for it (Skip lets it finish in the background).
  PhoneCheckRun start() {
    final PhoneCheckRun run = PhoneCheckRun._();
    unawaited(_run(run));
    return run;
  }

  Future<void> _run(PhoneCheckRun run) async {
    final int total = _runner.stepCount + extraSteps;
    int done = 0;
    try {
      final StorageVerdict room = StorageBudget.check(
        needed: StorageBudget.phoneCheckBytes,
        free: await _freeSpace.freeBytes(),
      );
      if (room case StorageShort(:final int shortfallBytes)) {
        _logger.warning(
          _tag,
          'No room for the phone check: $shortfallBytes bytes short',
        );
        return _end(run, null);
      }
      final DeviceMediaCheckRun media = _runner.start(
        onStep: (DeviceMediaCheckStep step) {
          done = step.index;
          run._progress.add(switch (step) {
            EncodeStep(:final format) => PhoneCheckProgress(
              test: PhoneCheckTest.encode,
              done: done,
              total: total,
              format: format,
            ),
            DecodeStep() => PhoneCheckProgress(
              test: PhoneCheckTest.decode,
              done: done,
              total: total,
            ),
          });
        },
      );
      run._media = media;
      final DeviceMediaCheckResult found = await media.result;
      if (run.isCancelled) return _end(run, null);

      run._progress.add(
        PhoneCheckProgress(
          test: PhoneCheckTest.camera,
          done: total - extraSteps,
          total: total,
        ),
      );
      final CameraCapability? camera = await _probeCamera();
      if (run.isCancelled) return _end(run, null);

      run._progress.add(
        PhoneCheckProgress(
          test: PhoneCheckTest.storage,
          done: total - 1,
          total: total,
        ),
      );
      final int? freeBytes = await _freeSpace.freeBytes();
      if (run.isCancelled) return _end(run, null);

      final DeviceMediaProfile profile = DeviceMediaProfile(
        checkedAt: _clock.now(),
        appVersion: await _store.appVersion(),
        deviceModel: await _store.deviceModel(),
        encode: found.encode,
        decode: found.decode,
        camera: camera,
        freeBytes: freeBytes,
      );
      await _store.write(profile);
      _logger.info(
        _tag,
        'Checked ${profile.deviceModel}: ${_summary(profile)}',
      );
      _end(run, profile);
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'The phone check did not finish',
        error: error,
        stackTrace: stackTrace,
      );
      _end(run, null);
    }
  }

  /// The camera probe, only with the permission already granted: the
  /// check never prompts.
  Future<CameraCapability?> _probeCamera() async {
    final AccessOutcome access = await _permissions.check(
      PermissionFeature.recording,
    );
    if (access != AccessOutcome.granted) {
      _logger.info(_tag, 'No camera permission yet: the camera is unknown');
      return null;
    }
    return _camera.probe();
  }

  void _end(PhoneCheckRun run, DeviceMediaProfile? profile) {
    if (!run._result.isCompleted) run._result.complete(profile);
    unawaited(run._progress.close());
  }

  static String _summary(DeviceMediaProfile profile) {
    final List<String> passed = <String>[
      for (final MapEntry<String, EncodeResult> entry in profile.encode.entries)
        if (entry.value.ok)
          '${entry.key} ${entry.value.realtimeFactor?.toStringAsFixed(2)}x',
    ];
    final CameraCapability? camera = profile.camera;
    return 'encode ${passed.join(', ')}; camera '
        '${camera == null ? 'unknown' : '${camera.maxTier.token}p'
                  '${camera.fps60 ? '60' : '30'} ${camera.channels}ch'}; '
        'free ${profile.freeBytes}';
  }
}
