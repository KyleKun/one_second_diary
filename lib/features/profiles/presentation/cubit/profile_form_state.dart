import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_deletion.dart';
import 'package:one_second_diary/features/profiles/domain/profile_name_error.dart';
import 'package:one_second_diary/features/profiles/domain/quality_recommender.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_target.dart';

/// What the profile form is doing.
///
/// Every attempt starts from an in-progress status ([pickingPhoto],
/// [saving]), so each failure is a new transition that a `BlocListener`
/// sees, however many come in a row.
enum ProfileFormStatus {
  /// The user is filling it in.
  editing,

  /// The photo picker is open.
  pickingPhoto,

  /// The phone refused the camera or the photos the picker needs
  /// ([ProfileFormState.deniedOrigin]).
  photoDenied,

  /// The picked photo could not be handed over (an iCloud item that did
  /// not download).
  photoUnavailable,

  /// The profile is being stored; the sheet can't be dismissed.
  saving,

  /// The profile is stored ([ProfileFormState.created] for a new one).
  saved,

  /// The phone refused to store it; nothing changed.
  saveFailed,

  /// The profile and its clips are being deleted (Android may ask for
  /// consent for each clip a previous install made); the sheet can't be
  /// dismissed.
  deleting,

  /// The profile is gone ([ProfileFormState.deletion] says what stayed).
  deleted,

  /// The phone refused to delete it; the profile is kept.
  deleteFailed,
}

/// The profile form: the display name as typed, the canvas, the quality,
/// the photo.
final class ProfileFormState extends Equatable {
  const ProfileFormState({
    required this.target,
    this.name = '',
    this.nameEdited = false,
    this.nameError,
    this.orientation,
    this.format,
    this.recommendation,
    this.originalName = '',
    this.storedPhoto,
    this.photoRemoved = false,
    this.pickedPhoto,
    this.isDefault = false,
    this.deniedOrigin,
    this.created,
    this.deletion,
    this.status = ProfileFormStatus.editing,
  });

  /// The profile being created or edited.
  final ProfileFormTarget target;

  /// The display name as typed (trimmed when stored).
  final String name;

  /// Whether the user has typed in the name field.
  final bool nameEdited;

  /// Why [name] can't be stored, or null when it can.
  final ProfileNameError? nameError;

  /// The canvas: chosen once for a new profile, fixed for an existing one.
  final VideoOrientation? orientation;

  /// The clip format: the phone check's pick for a new
  /// profile until the user picks another in the quality sheet, carried
  /// on [orientation]'s canvas; fixed for an existing one. Null for a new
  /// profile until its canvas is chosen.
  final ClipFormat? format;

  /// What the phone check says, for the quality sheet: on [orientation]'s
  /// canvas (landscape until one is chosen). Null for an existing
  /// profile.
  final QualityRecommendation? recommendation;

  /// The name the edited profile shows now (`''` for a new one).
  final String originalName;

  /// The edited profile's photo, relative to internal storage.
  final String? storedPhoto;

  /// Whether the user removed [storedPhoto] (it goes on Save).
  final bool photoRemoved;

  /// A photo just picked (the picker's file), stored on Save.
  final String? pickedPhoto;

  /// Whether the edited profile is Default, which can't be deleted.
  final bool isDefault;

  /// Where the refused photo was to come from.
  final PhotoOrigin? deniedOrigin;

  /// The profile Create made.
  final Profile? created;

  /// What deleting the profile left on the phone.
  final ProfileDeletion? deletion;

  final ProfileFormStatus status;

  /// The error the name field shows: none for an empty name the user has
  /// not typed yet (a new profile's form opens empty), since Save is simply
  /// off then.
  ProfileNameError? get shownNameError =>
      nameError == ProfileNameError.empty && !nameEdited ? null : nameError;

  /// Whether the form shows a photo: one just picked, or the stored one
  /// unless removed.
  bool get hasPhoto =>
      pickedPhoto != null || (!photoRemoved && storedPhoto != null);

  /// Whether "Delete profile" shows: an existing profile other than
  /// Default.
  bool get canDelete => target is EditProfileForm && !isDefault;

  /// Whether the form is storing or deleting (no edits, no dismiss).
  bool get isBusy =>
      status == ProfileFormStatus.saving ||
      status == ProfileFormStatus.deleting;

  bool get canSave => nameError == null && orientation != null && !isBusy;

  ProfileFormState copyWith({
    String? name,
    bool? nameEdited,
    ProfileNameError? Function()? nameError,
    VideoOrientation? orientation,
    ClipFormat? format,
    QualityRecommendation? recommendation,
    String? Function()? pickedPhoto,
    bool? photoRemoved,
    PhotoOrigin? deniedOrigin,
    Profile? created,
    ProfileDeletion? deletion,
    ProfileFormStatus? status,
  }) => ProfileFormState(
    target: target,
    name: name ?? this.name,
    nameEdited: nameEdited ?? this.nameEdited,
    nameError: nameError == null ? this.nameError : nameError(),
    orientation: orientation ?? this.orientation,
    format: format ?? this.format,
    recommendation: recommendation ?? this.recommendation,
    originalName: originalName,
    storedPhoto: storedPhoto,
    photoRemoved: photoRemoved ?? this.photoRemoved,
    pickedPhoto: pickedPhoto == null ? this.pickedPhoto : pickedPhoto(),
    isDefault: isDefault,
    deniedOrigin: deniedOrigin ?? this.deniedOrigin,
    created: created ?? this.created,
    deletion: deletion ?? this.deletion,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => <Object?>[
    target,
    name,
    nameEdited,
    nameError,
    orientation,
    format,
    recommendation,
    originalName,
    storedPhoto,
    photoRemoved,
    pickedPhoto,
    isDefault,
    deniedOrigin,
    created,
    deletion,
    status,
  ];
}
