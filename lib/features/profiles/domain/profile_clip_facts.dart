import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// The probed facts of a profile folder's newest clips, for inferring what a
/// profile found after a reinstall was made for (`ProfileFormatInference`).
/// The profile need not be listed. Faked in tests.
abstract interface class ProfileClipFacts {
  /// The facts of up to [count] newest clips of [profile], newest first;
  /// empty when the folder holds none or none can be read. Never throws.
  Future<List<ClipMeta>> newestOf(ProfileKey profile, {int count = 3});
}
