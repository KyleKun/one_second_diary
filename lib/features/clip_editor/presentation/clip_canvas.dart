import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_state.dart';

/// The canvas a clip is made in: the orientation of the profile it goes
/// to, or of the active profile when that one is gone (a profile deleted
/// while the editor was open).
abstract final class ClipCanvas {
  static VideoOrientation of(ProfilesState profiles, ProfileKey profile) =>
      _profileOf(profiles, profile).orientation;

  /// The format a clip is made in: the profile's write-once format on its canvas (`Profile.format`),
  /// with the same fallback to the active profile.
  static ClipFormat formatOf(ProfilesState profiles, ProfileKey profile) =>
      _profileOf(profiles, profile).format;

  static Profile _profileOf(ProfilesState profiles, ProfileKey profile) =>
      profiles.profiles.firstWhere(
        (Profile candidate) => candidate.key == profile,
        orElse: () => profiles.active,
      );
}
