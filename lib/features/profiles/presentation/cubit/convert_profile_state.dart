import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/features/clips/domain/clip_conversion.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_name_error.dart';
import 'package:one_second_diary/features/profiles/domain/quality_recommender.dart';

/// Where the "Convert into a new profile" sheet stands.
enum ConvertProfileStatus {
  /// The user names the new profile and picks its quality.
  editing,

  /// The estimate for the target is being computed.
  estimating,

  /// The new profile is being made; the sheet can't be dismissed.
  starting,

  /// The clips are being converted into it; the sheet shows the progress
  /// and can't be dismissed (Stop ends the run after the clip in flight).
  running,

  /// Every clip went through (or was skipped): "Converted into {name}".
  done,

  /// The run was stopped; what was converted is kept in the new profile.
  cancelled,

  /// The profile could not be made (a name taken meanwhile, a folder that
  /// cannot be written) or the converter failed before it finished.
  startFailed,
}

/// The sheet of a conversion: the source profile, the new name, the target
/// quality, the estimate, then the run.
final class ConvertProfileState extends Equatable {
  const ConvertProfileState({
    required this.source,
    required this.recommendation,
    this.name = '',
    this.nameError,
    this.nameEdited = false,
    this.target,
    this.estimate,
    this.status = ConvertProfileStatus.editing,
    this.created,
    this.progress,
    this.report,
  });

  /// The profile whose clips are converted (never changed).
  final Profile source;

  /// For the quality sheet.
  final QualityRecommendation recommendation;

  /// The new profile's name as typed.
  final String name;
  final ProfileNameError? nameError;
  final bool nameEdited;

  /// The target format on the source's canvas; null until the user picks
  /// one (the sheet pre-fills the recommendation's pick).
  final ClipFormat? target;

  /// The converter's estimate for [target], once computed.
  final ConversionEstimate? estimate;

  final ConvertProfileStatus status;

  /// The new profile, once made (from [ConvertProfileStatus.running] on).
  final Profile? created;

  /// The run's latest progress ("n of N · about 12 min left").
  final ConversionProgress? progress;

  /// What the run did, once it ended.
  final ConversionReport? report;

  /// The error the name field shows: none for an empty name not typed
  /// yet.
  ProfileNameError? get shownNameError =>
      nameError == ProfileNameError.empty && !nameEdited ? null : nameError;

  /// Whether [target] is the source's own format: not offered.
  bool get sameQuality => target != null && target == source.format;

  /// Whether the sheet may not be dismissed: the profile is being made or
  /// the clips converted.
  bool get isBusy =>
      status == ConvertProfileStatus.starting ||
      status == ConvertProfileStatus.running;

  /// Whether the run ended, one way or the other.
  bool get isOver =>
      status == ConvertProfileStatus.done ||
      status == ConvertProfileStatus.cancelled;

  /// Whether "Convert" is on: a valid name, another quality, an estimate
  /// that fits.
  bool get canStart =>
      nameError == null &&
      target != null &&
      !sameQuality &&
      estimate != null &&
      estimate!.canStart &&
      status == ConvertProfileStatus.editing;

  ConvertProfileState copyWith({
    String? name,
    ProfileNameError? Function()? nameError,
    bool? nameEdited,
    ClipFormat? target,
    ConversionEstimate? Function()? estimate,
    ConvertProfileStatus? status,
    Profile? created,
    ConversionProgress? progress,
    ConversionReport? report,
  }) => ConvertProfileState(
    source: source,
    recommendation: recommendation,
    name: name ?? this.name,
    nameError: nameError == null ? this.nameError : nameError(),
    nameEdited: nameEdited ?? this.nameEdited,
    target: target ?? this.target,
    estimate: estimate == null ? this.estimate : estimate(),
    status: status ?? this.status,
    created: created ?? this.created,
    progress: progress ?? this.progress,
    report: report ?? this.report,
  );

  @override
  List<Object?> get props => <Object?>[
    source,
    recommendation,
    name,
    nameError,
    nameEdited,
    target,
    estimate,
    status,
    created,
    progress,
    report,
  ];
}
