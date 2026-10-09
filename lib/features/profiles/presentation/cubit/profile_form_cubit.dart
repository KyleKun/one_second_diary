import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/features/profiles/data/device_media_profile_store.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_deletion.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/domain/profile_name_error.dart';
import 'package:one_second_diary/features/profiles/domain/quality_recommender.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_state.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_target.dart';

/// The form behind "New profile" and "Edit profile", over
/// [ProfilesRepository].
///
/// - **Name:** any script, checked as typed; stored trimmed. Renaming changes
///   only the display name.
/// - **Canvas:** chosen once at creation (no default: the choice is
///   permanent), never changed after.
/// - **Quality:** the phone check's pick for the canvas, or what the user
///   picks in the quality sheet; written once with the profile.
/// - **Photo:** stored on Save in private storage.
class ProfileFormCubit extends Cubit<ProfileFormState> {
  /// [deviceProfile] is the stored phone check, read as the form opens;
  /// [isIOS] decides stereo in the recommendation.
  ProfileFormCubit({
    required ProfileFormTarget target,
    required this._profiles,
    required this._picker,
    required this._deviceProfile,
    required this._isIOS,
    required this._logger,
  }) : super(_initial(target, _profiles)) {
    if (target is NewProfileForm) unawaited(_loadRecommendation());
  }

  final ProfilesRepository _profiles;
  final PickerGateway _picker;
  final DeviceMediaProfileStore _deviceProfile;
  final bool _isIOS;
  final AppLogger _logger;

  /// Whether the user picked a quality themselves: the recommendation
  /// then no longer moves the choice.
  bool _formatPicked = false;

  static const String _tag = 'PROFILES';

  static ProfileFormState _initial(
    ProfileFormTarget target,
    ProfilesRepository profiles,
  ) => switch (target) {
    NewProfileForm() => ProfileFormState(
      target: target,
      nameError: profiles.validateNewName(''),
    ),
    EditProfileForm(profile: final ProfileKey key) => _editing(
      target,
      profiles.profiles.firstWhere(
        (Profile profile) => profile.key == key,
        orElse: () => throw ArgumentError.value(key, 'profile', 'not listed'),
      ),
    ),
  };

  static ProfileFormState _editing(ProfileFormTarget target, Profile profile) =>
      ProfileFormState(
        target: target,
        name: profile.displayName,
        originalName: profile.displayName,
        orientation: profile.orientation,
        format: profile.format,
        storedPhoto: profile.avatarRelPath,
        isDefault: profile.isDefault,
      );

  void nameChanged(String name) => emit(
    state.copyWith(
      name: name,
      nameEdited: true,
      nameError: () => _validate(name),
    ),
  );

  /// A new profile's canvas was chosen: the quality follows it (the
  /// recommendation's pick on that canvas, or the user's own pick carried
  /// over).
  void orientationPicked(VideoOrientation orientation) {
    final QualityRecommendation? advice = state.recommendation == null
        ? null
        : _recommend(orientation);
    final ClipFormat? current = state.format;
    emit(
      state.copyWith(
        orientation: orientation,
        recommendation: advice,
        format: _formatPicked && current != null
            ? current.withOrientation(orientation)
            : advice?.pick ?? ClipFormatPreset.standard.format(orientation),
      ),
    );
  }

  /// A new profile's quality was picked in the quality sheet.
  void formatPicked(ClipFormat format) {
    if (state.target is! NewProfileForm || state.isBusy) return;
    _formatPicked = true;
    final VideoOrientation? orientation = state.orientation;
    emit(
      state.copyWith(
        format: orientation == null
            ? format
            : format.withOrientation(orientation),
      ),
    );
  }

  /// Reads the stored phone check (null when it never ran or is stale)
  /// and recommends for the canvas chosen so far (landscape until one
  /// is).
  Future<void> _loadRecommendation() async {
    final DeviceMediaProfile? profile = await _deviceProfile.current();
    if (isClosed) return;
    _profile = profile;
    final VideoOrientation? orientation = state.orientation;
    final QualityRecommendation advice = _recommend(
      orientation ?? VideoOrientation.landscape,
    );
    emit(
      state.copyWith(
        recommendation: advice,
        format: _formatPicked || orientation == null ? null : advice.pick,
      ),
    );
  }

  DeviceMediaProfile? _profile;

  QualityRecommendation _recommend(VideoOrientation orientation) =>
      QualityRecommender.recommend(
        profile: _profile,
        orientation: orientation,
        isIOS: _isIOS,
      );

  /// Takes or chooses a photo ([origin]); it shows at once and is stored on
  /// Save.
  Future<void> pickPhoto(PhotoOrigin origin) async {
    emit(state.copyWith(status: ProfileFormStatus.pickingPhoto));
    final PickerOutcome outcome = await _picker.pickProfilePhoto(
      origin: origin,
    );
    if (isClosed) return;
    emit(switch (outcome) {
      Picked(:final String path) => state.copyWith(
        pickedPhoto: () => path,
        status: ProfileFormStatus.editing,
      ),
      PickCancelled() => state.copyWith(status: ProfileFormStatus.editing),
      PickDenied() => state.copyWith(
        deniedOrigin: origin,
        status: ProfileFormStatus.photoDenied,
      ),
      PickUnavailable() => state.copyWith(
        status: ProfileFormStatus.photoUnavailable,
      ),
    });
  }

  /// Removes the photo: the initial shows instead, and the photo goes on
  /// Save.
  void removePhoto() =>
      emit(state.copyWith(pickedPhoto: () => null, photoRemoved: true));

  /// Stores the form: creates the profile (it becomes the active one) or
  /// saves the edits.
  Future<void> save() async {
    if (!state.canSave) return;
    emit(state.copyWith(status: ProfileFormStatus.saving));
    try {
      switch (state.target) {
        case NewProfileForm():
          await _create();
        case EditProfileForm(:final ProfileKey profile):
          await _edit(profile);
      }
    } on StorageException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not save the profile',
        error: error,
        stackTrace: stackTrace,
      );
      if (!isClosed) emit(state.copyWith(status: ProfileFormStatus.saveFailed));
    }
  }

  /// Deletes the profile with every clip in its folder. Android asks for
  /// consent for each clip a previous install made; the clips it keeps are
  /// reported in [ProfileFormState.deletion], and the profile goes anyway
  /// (its folder then shows under "Found on this phone"). Default is never
  /// deleted.
  Future<void> delete() async {
    final ProfileFormTarget target = state.target;
    if (target is! EditProfileForm || !state.canDelete || state.isBusy) return;
    emit(state.copyWith(status: ProfileFormStatus.deleting));
    try {
      final ProfileDeletion deletion = await _profiles.delete(target.profile);
      if (!isClosed) {
        emit(
          state.copyWith(deletion: deletion, status: ProfileFormStatus.deleted),
        );
      }
    } on StorageException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not delete profile "${target.profile.albumLabel}"',
        error: error,
        stackTrace: stackTrace,
      );
      if (!isClosed) {
        emit(state.copyWith(status: ProfileFormStatus.deleteFailed));
      }
    }
  }

  Future<void> _create() async {
    final Profile created = await _profiles.create(
      displayName: state.name,
      orientation: state.orientation!,
      format: state.format,
    );
    final String? photo = state.pickedPhoto;
    if (photo != null) {
      try {
        await _profiles.setPhoto(key: created.key, imagePath: photo);
      } on StorageException catch (error, stackTrace) {
        // The profile exists and is active; only its photo is missing, and
        // "Edit profile" can add it.
        _logger.warning(
          _tag,
          'Could not store the photo of the new profile',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    if (!isClosed) {
      emit(
        state.copyWith(
          created: _profiles.active,
          status: ProfileFormStatus.saved,
        ),
      );
    }
  }

  Future<void> _edit(ProfileKey key) async {
    final String? picked = state.pickedPhoto;
    if (picked != null) {
      await _profiles.setPhoto(key: key, imagePath: picked);
    } else if (state.photoRemoved && state.storedPhoto != null) {
      await _profiles.removePhoto(key);
    }
    final String name = state.name.trim();
    if (name != state.originalName) {
      await _profiles.rename(key: key, displayName: name);
    }
    if (!isClosed) emit(state.copyWith(status: ProfileFormStatus.saved));
  }

  ProfileNameError? _validate(String name) => switch (state.target) {
    NewProfileForm() => _profiles.validateNewName(name),
    EditProfileForm(:final profile) => _profiles.validateRename(
      key: profile,
      displayName: name,
    ),
  };
}

/// Makes the form of one profile sheet. The sheets open from any page where
/// no route provides the form, so the app root provides this factory.
typedef ProfileFormFactory =
    ProfileFormCubit Function(ProfileFormTarget target);
