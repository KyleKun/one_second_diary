import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/features/clips/domain/clip_conversion.dart';
import 'package:one_second_diary/features/profiles/data/device_media_profile_store.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/domain/quality_recommender.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/convert_profile_state.dart';

/// "Convert into a new profile": the new profile's name, its quality from the
/// same picker as the profile forms, and the converter's estimate. "Convert"
/// makes the profile and runs the converter ([ProfileConversionStarter]) into
/// it, following its progress; Stop cancels after the clip in flight (what
/// was converted is kept).
class ConvertProfileCubit extends Cubit<ConvertProfileState> {
  /// [defaultNameOf] gives the pre-filled name for the source's name and
  /// the target's short quality label ("Travel 4K"), in the app language.
  ConvertProfileCubit({
    required ProfileKey source,
    required this._profiles,
    required this._converter,
    required this._deviceProfile,
    required this._isIOS,
    required this._defaultNameOf,
    required this._logger,
  }) : super(_initial(source, _profiles, isIOS: _isIOS)) {
    unawaited(_open());
  }

  final ProfilesRepository _profiles;
  final ProfileConversionStarter _converter;
  final DeviceMediaProfileStore _deviceProfile;
  final bool _isIOS;
  final String Function(String name, ClipFormat target) _defaultNameOf;
  final AppLogger _logger;

  static const String _tag = 'PROFILES';

  /// Whether the user typed a name: the pre-fill then stops following
  /// the target.
  bool _nameTyped = false;

  int _estimateSerial = 0;

  CancelToken? _cancel;
  StreamSubscription<ConversionEvent>? _run;

  static ConvertProfileState _initial(
    ProfileKey source,
    ProfilesRepository profiles, {
    required bool isIOS,
  }) {
    final Profile profile = profiles.profiles.firstWhere(
      (Profile profile) => profile.key == source,
      orElse: () => throw ArgumentError.value(source, 'source', 'not listed'),
    );
    return ConvertProfileState(
      source: profile,
      recommendation: QualityRecommender.recommend(
        profile: null,
        orientation: profile.orientation,
        isIOS: isIOS,
      ),
    );
  }

  /// Reads the phone check, pre-fills the target with its pick (Ultra's
  /// best when the source already has the pick) and the name, and asks
  /// for the first estimate.
  Future<void> _open() async {
    final DeviceMediaProfile? checked = await _deviceProfile.current();
    if (isClosed) return;
    final QualityRecommendation advice = QualityRecommender.recommend(
      profile: checked,
      orientation: state.source.orientation,
      isIOS: _isIOS,
    );
    ClipFormat target = advice.pick;
    if (target == state.source.format) {
      target =
          advice.presetFormat(ClipFormatPreset.ultra) ??
          advice.presetFormat(ClipFormatPreset.high) ??
          target;
    }
    emit(
      ConvertProfileState(
        source: state.source,
        recommendation: advice,
        name: _defaultNameOf(state.source.displayName, target),
        nameError: _profiles.validateNewName(
          _defaultNameOf(state.source.displayName, target),
        ),
        target: target,
      ),
    );
    await _estimate(target);
  }

  void nameChanged(String name) {
    if (state.status != ConvertProfileStatus.editing &&
        state.status != ConvertProfileStatus.estimating) {
      return;
    }
    _nameTyped = true;
    emit(
      state.copyWith(
        name: name,
        nameEdited: true,
        nameError: () => _profiles.validateNewName(name),
      ),
    );
  }

  /// The quality sheet picked [format].
  Future<void> targetPicked(ClipFormat format) async {
    if (state.status != ConvertProfileStatus.editing &&
        state.status != ConvertProfileStatus.estimating) {
      return;
    }
    final ClipFormat target = format.withOrientation(state.source.orientation);
    final String name = _nameTyped
        ? state.name
        : _defaultNameOf(state.source.displayName, target);
    emit(
      state.copyWith(
        target: target,
        name: name,
        nameError: () => _profiles.validateNewName(name),
        estimate: () => null,
      ),
    );
    await _estimate(target);
  }

  Future<void> _estimate(ClipFormat target) async {
    final int serial = ++_estimateSerial;
    if (target == state.source.format) {
      // Not offered: nothing to estimate, and an estimate still in flight
      // for another target must not land on this one.
      emit(
        state.copyWith(
          estimate: () => null,
          status: ConvertProfileStatus.editing,
        ),
      );
      return;
    }
    emit(state.copyWith(status: ConvertProfileStatus.estimating));
    try {
      final ConversionEstimate estimate = await _converter.estimateConversion(
        source: state.source.key,
        format: target,
      );
      if (isClosed || serial != _estimateSerial) return;
      emit(
        state.copyWith(
          estimate: () => estimate,
          status: ConvertProfileStatus.editing,
        ),
      );
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not estimate the conversion of "${state.source.key.value}"',
        error: error,
        stackTrace: stackTrace,
      );
      if (isClosed || serial != _estimateSerial) return;
      emit(
        state.copyWith(
          estimate: () => null,
          status: ConvertProfileStatus.editing,
        ),
      );
    }
  }

  /// "Convert": makes the new profile with the target format and starts
  /// converting the source's clips into it.
  Future<void> start() async {
    if (!state.canStart) return;
    final ClipFormat target = state.target!;
    emit(state.copyWith(status: ConvertProfileStatus.starting));
    final Profile created;
    try {
      created = await _profiles.create(
        displayName: state.name.trim(),
        orientation: state.source.orientation,
        format: target,
      );
    } on Object catch (error, stackTrace) {
      // An ArgumentError (a name taken meanwhile) or a StorageException.
      _failed('Could not make the profile to convert into', error, stackTrace);
      return;
    }
    if (isClosed) return;
    final CancelToken cancel = CancelToken();
    _cancel = cancel;
    emit(
      state.copyWith(status: ConvertProfileStatus.running, created: created),
    );
    _run = _converter
        .convertProfile(
          ConversionJob(
            source: state.source.key,
            target: created.key,
            format: target,
          ),
          cancelToken: cancel,
        )
        .listen(
          _event,
          onError: (Object error, StackTrace stackTrace) => _failed(
            'The conversion into "${created.key.value}" failed',
            error,
            stackTrace,
          ),
        );
  }

  /// Stop: ends the run after the clip in flight.
  void cancel() {
    if (state.status != ConvertProfileStatus.running) return;
    _cancel?.cancel();
  }

  void _event(ConversionEvent event) {
    if (isClosed) return;
    switch (event) {
      case ConversionProgress():
        emit(
          state.copyWith(status: ConvertProfileStatus.running, progress: event),
        );
      case ConversionFinished(:final ConversionReport report):
        emit(
          state.copyWith(
            status: report.cancelled
                ? ConvertProfileStatus.cancelled
                : ConvertProfileStatus.done,
            report: report,
          ),
        );
      case ConversionClipDone() || ConversionClipSkipped():
        break;
    }
  }

  void _failed(String what, Object error, StackTrace stackTrace) {
    _logger.error(_tag, what, error: error, stackTrace: stackTrace);
    if (!isClosed) {
      emit(state.copyWith(status: ConvertProfileStatus.startFailed));
    }
  }

  @override
  Future<void> close() async {
    await _run?.cancel();
    await super.close();
  }
}
