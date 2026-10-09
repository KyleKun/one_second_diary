import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/permissions/access_outcome.dart';
import 'package:one_second_diary/core/permissions/permission_feature.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/device_info_gateway.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/onboarding/data/onboarding_store.dart';
import 'package:one_second_diary/features/onboarding/domain/onboarding_permission.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/setting.dart';

/// The onboarding flow: the intro carousel, the Default profile's
/// orientation and the optional name, the permissions step (one "Allow"
/// per permission the app uses), the phone check (where the Default
/// profile's quality is chosen) and the finish that makes the diary.
class OnboardingCubit extends Cubit<OnboardingState> {
  /// [userName] is `SettingsRepository.userName`: the name field starts
  /// from what an interrupted onboarding stored. [forceNativeCamera] is
  /// `SettingsRepository.forceNativeCamera`, which with [deviceInfo]
  /// decides the rows of the permissions step.
  OnboardingCubit({
    required this._store,
    required this._permissions,
    required this._deviceInfo,
    required this._forceNativeCamera,
    required this._profiles,
    required Setting<String> userName,
    required this._clips,
    required Clock clock,
    required this._logger,
  }) : _userName = userName,
       super(
         OnboardingState(
           today: LocalDay.fromDateTime(clock.now()),
           name: userName.value,
         ),
       ) {
    _fixedOrientation = _findFixedOrientation();
    _rows = _findRows();
  }

  final OnboardingStore _store;
  final PermissionRequester _permissions;
  final DeviceInfoGateway _deviceInfo;
  final Setting<bool> _forceNativeCamera;
  final ProfilesRepository _profiles;
  final Setting<String> _userName;
  final ClipRepository _clips;
  final AppLogger _logger;

  static const String _tag = 'ONBOARDING';

  late final Future<VideoOrientation?> _fixedOrientation;

  /// The rows the permissions step shows on this phone.
  late final Future<List<OnboardingPermission>> _rows;

  /// Whether the user has answered the gallery request (on the permissions
  /// step, or at the finish): once they have, going on never asks again
  /// (only "Allow access" does).
  bool _accessAnswered = false;

  /// The Default profile's canvas the finish makes: the fixed one on the
  /// reinstall path, or the user's pick. Null until the permissions step
  /// opens.
  VideoOrientation? _target;

  /// Whether the canvas was already decided when the intro was left (a
  /// reinstall): the permissions step then sits above the intro, not above
  /// the orientation step.
  bool _skippedOrientation = false;

  /// The Default profile's clip format the finish writes: the phone
  /// check's choice ([startDiary]), kept for a retry after a refusal.
  /// Null leaves it to the store (a reinstall's inferred format, else
  /// absent, which reads as Standard).
  ClipFormat? _format;

  /// The Default profile's canvas when it is already decided (a reinstall,
  /// or an onboarding killed after storing it), so the orientation step
  /// must not ask (`OnboardingStore.fixedDefaultOrientation`). Looked for
  /// as soon as onboarding opens, before anything makes the diary folder,
  /// and only with a check: no permission is requested before the user
  /// taps for it.
  Future<VideoOrientation?> _findFixedOrientation() async {
    final AccessOutcome gallery = await _galleryAccess(
      _permissions.check,
      'check',
    );
    return _store.fixedDefaultOrientation(
      canReadGallery: gallery == AccessOutcome.granted,
    );
  }

  /// The rows this phone shows, from its Android version and the "Force
  /// native camera" preference. A phone that cannot say its version shows
  /// every row rather than hiding one it needs.
  Future<List<OnboardingPermission>> _findRows() async {
    try {
      return OnboardingPermission.rowsFor(
        androidSdkInt: await _deviceInfo.androidSdkInt(),
        forceNativeCamera: _forceNativeCamera.value,
      );
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not read the Android version for the permissions step',
        error: error,
        stackTrace: stackTrace,
      );
      return OnboardingPermission.values;
    }
  }

  /// [ask] for the gallery ([PermissionFeature.mediaLibrary]). A plugin
  /// that fails (permission_handler throws while another request runs)
  /// counts as denied, so the flow never waits on it.
  Future<AccessOutcome> _galleryAccess(
    Future<AccessOutcome> Function(PermissionFeature feature) ask,
    String what,
  ) => _access(PermissionFeature.mediaLibrary, ask, what);

  Future<AccessOutcome> _access(
    PermissionFeature feature,
    Future<AccessOutcome> Function(PermissionFeature feature) ask,
    String what,
  ) async {
    try {
      return await ask(feature);
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not $what the access for ${feature.name}',
        error: error,
        stackTrace: stackTrace,
      );
      return AccessOutcome.denied;
    }
  }

  /// Leaves the intro carousel (Next on the last slide) for the
  /// orientation step, or straight for the permissions step when the
  /// canvas is already decided.
  Future<void> leaveIntro() async {
    final VideoOrientation? fixed = await _fixedOrientation;
    if (state.isBusy) return;
    if (fixed != null) {
      _skippedOrientation = true;
      return _openPermissions(fixed);
    }
    emit(state.copyWith(step: OnboardingStep.orientation));
  }

  /// The orientation step was left with back (system back, the iOS edge
  /// swipe): the intro shows again, and the choices are kept.
  void orientationClosed() {
    if (state.isBusy) return;
    emit(state.copyWith(step: OnboardingStep.intro));
  }

  /// Picks the Default profile's orientation.
  void pickOrientation(VideoOrientation orientation) {
    if (state.isBusy) return;
    emit(state.copyWith(orientation: orientation));
  }

  /// The optional name field changed.
  void nameChanged(String name) {
    if (state.isBusy) return;
    emit(state.copyWith(name: name));
  }

  /// "Continue" on the orientation step: opens the permissions step with
  /// the orientation picked. Nothing is written or asked yet.
  Future<void> goToPermissions() async {
    final VideoOrientation? orientation = state.orientation;
    if (orientation == null || state.isBusy) return;
    _skippedOrientation = false;
    await _openPermissions(orientation);
  }

  /// Opens the permissions step for [target]: its rows show, and each is
  /// checked (never asked) so one already allowed shows "Allowed".
  Future<void> _openPermissions(VideoOrientation target) async {
    final List<OnboardingPermission> rows = await _rows;
    if (state.isBusy || state.step == OnboardingStep.permissions) return;
    _target = target;
    emit(
      state.copyWith(
        step: OnboardingStep.permissions,
        permissions:
            Map<OnboardingPermission, PermissionRowStatus>.unmodifiable(
              <OnboardingPermission, PermissionRowStatus>{
                // Answers given before back was pressed are kept.
                for (final OnboardingPermission row in rows)
                  row: state.permissions[row] ?? PermissionRowStatus.notAsked,
              },
            ),
      ),
    );
    await _checkRows();
  }

  /// The permissions step was left with back: the step below shows again
  /// (the orientation step, or the intro on the reinstall path), and the
  /// rows' answers are kept.
  void permissionsClosed() {
    if (state.isBusy || state.step != OnboardingStep.permissions) return;
    emit(
      state.copyWith(
        step: _skippedOrientation
            ? OnboardingStep.intro
            : OnboardingStep.orientation,
      ),
    );
  }

  /// "Continue" on the permissions step: opens the phone check,
  /// where the Default profile's quality is chosen. Nothing is written
  /// yet.
  void goToPhoneCheck() {
    if (_target == null || state.isBusy) return;
    if (state.step != OnboardingStep.permissions) return;
    emit(state.copyWith(step: OnboardingStep.phoneCheck));
  }

  /// The phone check was left with back: the permissions step shows again
  /// (the check itself is cancelled by its own cubit).
  void phoneCheckClosed() {
    if (state.isBusy || state.step != OnboardingStep.phoneCheck) return;
    emit(state.copyWith(step: OnboardingStep.permissions));
  }

  /// A row's button: "Allow" asks for the row's permission; on a blocked
  /// row ("Open settings") the system Settings page is the only place left
  /// to grant it. The gallery's answer here also serves the finish, which
  /// then asks nothing.
  Future<void> allow(OnboardingPermission row) async {
    final PermissionRowStatus? current = state.permissions[row];
    if (current == null || state.isBusy) return;
    switch (current) {
      case PermissionRowStatus.requesting || PermissionRowStatus.granted:
        return;
      case PermissionRowStatus.blocked:
        return openAccessSettings();
      case PermissionRowStatus.notAsked || PermissionRowStatus.denied:
        break;
    }
    _setRow(row, PermissionRowStatus.requesting);
    final AccessOutcome outcome = await _access(
      row.feature,
      _permissions.request,
      'ask for',
    );
    if (row == OnboardingPermission.gallery) _accessAnswered = true;
    _setRow(row, PermissionRowStatus.of(outcome));
  }

  /// The app came back to the front on the permissions step: a row the
  /// user granted in the system Settings turns "Allowed", and one blocked
  /// there shows "Open settings".
  Future<void> recheckPermissions() async {
    if (state.step != OnboardingStep.permissions) return;
    await _checkRows();
  }

  /// Checks (never asks) every row that is not allowed or being asked, and
  /// shows what the check can tell: granted, blocked, or, for a row that
  /// was blocked and no longer is, that the prompt can show again.
  Future<void> _checkRows() async {
    for (final OnboardingPermission row in state.shownRows) {
      final PermissionRowStatus? before = state.permissions[row];
      if (before == null ||
          before == PermissionRowStatus.granted ||
          before == PermissionRowStatus.requesting) {
        continue;
      }
      final AccessOutcome outcome = await _access(
        row.feature,
        _permissions.check,
        'check',
      );
      if (isClosed || state.step != OnboardingStep.permissions) return;
      final PermissionRowStatus? now = state.permissions[row];
      if (now != before) continue; // A tap answered meanwhile.
      final PermissionRowStatus next = switch (outcome) {
        AccessOutcome.granted => PermissionRowStatus.granted,
        AccessOutcome.blocked => PermissionRowStatus.blocked,
        AccessOutcome.denied =>
          before == PermissionRowStatus.blocked
              ? PermissionRowStatus.notAsked
              : before,
      };
      if (next != before) _setRow(row, next);
    }
  }

  void _setRow(OnboardingPermission row, PermissionRowStatus status) {
    if (!state.permissions.containsKey(row)) return;
    emit(state.copyWith(permissions: _rowsWith(row, status)));
  }

  Map<OnboardingPermission, PermissionRowStatus> _rowsWith(
    OnboardingPermission row,
    PermissionRowStatus status,
  ) => Map<OnboardingPermission, PermissionRowStatus>.unmodifiable(
    <OnboardingPermission, PermissionRowStatus>{
      ...state.permissions,
      row: status,
    },
  );

  /// "Use this", "Choose another" and "Skip" on the phone check (and
  /// "Start my diary" on a build without it): makes the diary with the
  /// orientation picked (or the fixed one), whatever was allowed, and the
  /// Default profile's quality [format] (its orientation is ignored;
  /// Skip passes Standard; null leaves a reinstall's own format, or none).
  Future<void> startDiary({ClipFormat? format}) async {
    final VideoOrientation? target = _target;
    if (target == null || state.isBusy) return;
    _format = format ?? _format;
    await _finish(target);
  }

  /// "Allow access", after a refusal: asks again, and goes on when the
  /// user grants it.
  Future<void> askAccessAgain() async {
    final VideoOrientation? target = _target;
    if (target == null || state.isBusy) return;
    _accessAnswered = false;
    await _finish(target);
  }

  /// "Try again" after a failure, or "Not now" after a refusal: finishes
  /// with what was chosen, without asking for access again.
  Future<void> continueSetup() async {
    final VideoOrientation? target = _target;
    if (target == null || state.isBusy) return;
    await _finish(target);
  }

  /// "Open settings", when access is blocked: the system Settings page is
  /// the only place left to grant it.
  Future<void> openAccessSettings() async {
    try {
      await _permissions.openSettings();
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not open the system Settings',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// A finish that outlives the flow (its route went away) still writes
  /// what it started, with no one left to tell.
  @override
  void emit(OnboardingState state) {
    if (isClosed) return;
    super.emit(state);
  }

  /// The app came back to the front while access was refused: the user
  /// may have granted it in Settings, and then the explanation goes.
  Future<void> recheckAccess() async {
    if (state.status != OnboardingStatus.accessRefused) return;
    final AccessOutcome access = await _galleryAccess(
      _permissions.check,
      'check',
    );
    if (access != AccessOutcome.granted) return;
    emit(
      state.copyWith(
        status: OnboardingStatus.choosing,
        permissions: state.permissions.containsKey(OnboardingPermission.gallery)
            ? _rowsWith(
                OnboardingPermission.gallery,
                PermissionRowStatus.granted,
              )
            : null,
      ),
    );
  }

  /// Makes the diary. The gallery is asked here only when its row was not
  /// tapped on the permissions step (or "Allow access" asks again); a
  /// refusal stops before anything is made and shows on the gallery row
  /// too.
  Future<void> _finish(VideoOrientation orientation) async {
    _target = orientation;
    emit(state.copyWith(status: OnboardingStatus.finishing));
    if (!_accessAnswered) {
      final AccessOutcome access = await _galleryAccess(
        _permissions.request,
        'ask for',
      );
      _accessAnswered = true;
      if (access != AccessOutcome.granted) {
        emit(
          state.copyWith(
            status: OnboardingStatus.accessRefused,
            access: access,
            permissions:
                state.permissions.containsKey(OnboardingPermission.gallery)
                ? _rowsWith(
                    OnboardingPermission.gallery,
                    PermissionRowStatus.of(access),
                  )
                : null,
          ),
        );
        return;
      }
    }
    try {
      final String name = state.name.trim();
      if (name.isNotEmpty) await _userName.set(name);
      await _store.complete(
        defaultOrientation: orientation,
        defaultFormat: _format,
      );
    } on StorageException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not complete onboarding',
        error: error,
        stackTrace: stackTrace,
      );
      emit(state.copyWith(status: OnboardingStatus.failed));
      return;
    }
    await _announceDefault();
    _listDefaultClips();
    emit(state.copyWith(status: OnboardingStatus.done));
  }

  /// Lists Default's folder again, without holding Today back: the launch
  /// listed it before the user answered the gallery request, so on a
  /// reinstall it could not see the earlier clips yet.
  void _listDefaultClips() {
    unawaited(
      _clips
          .rescan(ProfileKey.defaultProfile)
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stackTrace) => _logger.warning(
              _tag,
              'Could not list the Default clips after onboarding',
              error: error,
              stackTrace: stackTrace,
            ),
          ),
    );
  }

  /// Makes the app's profile state show Default as it now is: its canvas
  /// was written by the store, which the profiles don't announce on their
  /// own. Onboarding is already complete here, so a refusal only waits for
  /// the next launch.
  Future<void> _announceDefault() async {
    try {
      await _profiles.activate(ProfileKey.defaultProfile);
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not select the Default profile after onboarding',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
