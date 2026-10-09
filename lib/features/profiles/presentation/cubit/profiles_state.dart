import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Whether the last profile switch was stored.
///
/// Every switch starts with [activating], so each refusal is a new
/// transition to [activationFailed] that a `BlocListener` sees, however
/// many come in a row.
enum ProfilesStatus {
  /// [ProfilesState.active] is the profile new clips go to.
  ready,

  /// A switch is being stored.
  activating,

  /// The phone refused to store a switch; the active profile did not
  /// change.
  activationFailed,
}

/// The diary's profiles, the active one and how many clips each holds.
final class ProfilesState extends Equatable {
  ProfilesState({
    required List<Profile> profiles,
    required this.active,
    Map<ProfileKey, int> clipCounts = const <ProfileKey, int>{},
    this.status = ProfilesStatus.ready,
    ProfileKey? switchingTo,
  }) : switchingTo = status == ProfilesStatus.activating ? switchingTo : null,
       profiles = List<Profile>.unmodifiable(profiles),
       clipCounts = Map<ProfileKey, int>.unmodifiable(clipCounts);

  /// Every profile in list order, Default first.
  final List<Profile> profiles;

  /// The profile new clips are recorded into.
  final Profile active;

  /// The clips in each profile whose diary has been read.
  final Map<ProfileKey, int> clipCounts;

  final ProfilesStatus status;

  /// The profile a running switch goes to (its tile shows a spinner); null
  /// unless [status] is [ProfilesStatus.activating].
  final ProfileKey? switchingTo;

  /// The clips in [key]'s diary; null until its folder has been read.
  int? clipCountOf(ProfileKey key) => clipCounts[key];

  ProfilesState copyWith({
    List<Profile>? profiles,
    Profile? active,
    Map<ProfileKey, int>? clipCounts,
    ProfilesStatus? status,
    ProfileKey? switchingTo,
  }) => ProfilesState(
    profiles: profiles ?? this.profiles,
    active: active ?? this.active,
    clipCounts: clipCounts ?? this.clipCounts,
    status: status ?? this.status,
    switchingTo: switchingTo ?? this.switchingTo,
  );

  @override
  List<Object?> get props => <Object?>[
    profiles,
    active,
    clipCounts,
    status,
    switchingTo,
  ];
}
