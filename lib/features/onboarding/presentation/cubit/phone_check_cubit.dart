import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/onboarding/data/phone_check.dart';
import 'package:one_second_diary/features/onboarding/domain/phone_check_progress.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/phone_check_state.dart';
import 'package:one_second_diary/features/profiles/data/device_media_profile_store.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';
import 'package:one_second_diary/features/profiles/domain/quality_recommender.dart';

/// The phone check (onboarding and Settings "Check again"): runs [PhoneCheck]
/// and turns its result into a recommendation on [orientation].
///
/// Screen-scoped. Closing it (back) cancels a running check, unless the
/// user skipped: then the check finishes in the background and its result
/// serves the next profile. The format chosen here is written by whoever
/// finishes (the onboarding cubit's `startDiary`): this cubit only
/// recommends.
class PhoneCheckCubit extends Cubit<PhoneCheckState> {
  PhoneCheckCubit({
    required this._check,
    required this._store,
    required this._orientation,
    required this._isIOS,
    required this._logger,
  }) : super(const PhoneCheckState());

  final PhoneCheck _check;
  final DeviceMediaProfileStore _store;
  final VideoOrientation _orientation;
  final bool _isIOS;
  final AppLogger _logger;

  static const String _tag = 'PHONE_CHECK';

  PhoneCheckRun? _run;
  StreamSubscription<PhoneCheckProgress>? _progress;
  bool _skipped = false;

  /// Shows the stored result, if any, without running: the Settings page
  /// opens on it, with "Check again".
  Future<void> loadStored() async {
    final DeviceMediaProfile? stored = _store.read();
    if (stored == null || isClosed) return;
    final bool stale = await _store.isStale(stored);
    if (isClosed) return;
    _showResult(stored, stale: stale, status: PhoneCheckStatus.done);
  }

  /// Runs the check. A run already in flight is left alone.
  Future<void> start() async {
    if (state.isRunning) return;
    _skipped = false;
    final PhoneCheckRun run = _check.start();
    _run = run;
    emit(
      state.copyWith(
        status: PhoneCheckStatus.running,
        progress: () => null,
        selected: () => null,
      ),
    );
    _progress = run.progress.listen((PhoneCheckProgress progress) {
      if (!isClosed) emit(state.copyWith(progress: () => progress));
    });
    final DeviceMediaProfile? profile = await run.result;
    if (isClosed || _run != run) return;
    _run = null;
    if (profile == null) {
      if (run.isCancelled) return;
      _logger.warning(_tag, 'The check failed; Standard is selected');
      _showResult(null, stale: false, status: PhoneCheckStatus.failed);
      return;
    }
    _showResult(profile, stale: false, status: PhoneCheckStatus.done);
  }

  /// "Skip": Standard is selected now; a running check goes on in the
  /// background and stores its result for the next profile.
  void skip() {
    _skipped = true;
    _run = null;
    unawaited(_progress?.cancel());
    _progress = null;
    emit(
      state.copyWith(
        status: PhoneCheckStatus.skipped,
        progress: () => null,
        recommendation: () => QualityRecommender.recommend(
          profile: null,
          orientation: _orientation,
          isIOS: _isIOS,
        ),
        selected: () => ClipFormatPreset.standard.format(_orientation),
      ),
    );
  }

  /// "Choose another" picked [format] in the quality sheet.
  void select(ClipFormat format) => emit(
    state.copyWith(selected: () => format.withOrientation(_orientation)),
  );

  /// Stops a running check (back).
  Future<void> cancel() async {
    final PhoneCheckRun? run = _run;
    _run = null;
    unawaited(_progress?.cancel());
    _progress = null;
    if (run == null) return;
    await run.cancel();
    if (!isClosed && state.isRunning) {
      emit(state.copyWith(status: PhoneCheckStatus.idle, progress: () => null));
    }
  }

  void _showResult(
    DeviceMediaProfile? profile, {
    required bool stale,
    required PhoneCheckStatus status,
  }) {
    final QualityRecommendation recommendation = QualityRecommender.recommend(
      profile: stale ? null : profile,
      orientation: _orientation,
      isIOS: _isIOS,
    );
    emit(
      state.copyWith(
        status: status,
        progress: () => null,
        profile: () => profile,
        stale: stale,
        recommendation: () => recommendation,
        selected: () => recommendation.pick,
      ),
    );
  }

  @override
  Future<void> close() async {
    unawaited(_progress?.cancel());
    if (!_skipped) unawaited(_run?.cancel());
    return super.close();
  }
}
