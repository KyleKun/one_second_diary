import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Identifies one clip on disk.
///
/// Built from the path alone: [day] and [ordinal] are parsed from its file
/// name (`ClipNameCodec`), so they can never disagree with it.
final class ClipRef extends Equatable {
  /// The clip at [relPath]. Throws an [ArgumentError] when it is not a clip
  /// of [profile] (see [tryParse]).
  factory ClipRef({required ProfileKey profile, required String relPath}) =>
      tryParse(profile: profile, relPath: relPath) ??
      (throw ArgumentError.value(
        relPath,
        'relPath',
        'is not a clip of profile "${profile.value}"',
      ));

  const ClipRef._(this.profile, this.relPath, this.day, this.ordinal);

  /// The clip at [relPath], or null when its file name is not exactly a clip
  /// name or the path is not inside [profile]'s folder: a named profile's
  /// clips are under `Profiles/<key>/`; the Default profile's are anywhere
  /// else except the top-level `Profiles/` and `Movies/` folders (compared by
  /// path segment). Absolute and `..` paths are never clips.
  ///
  /// A named profile's folder is matched as the whole prefix
  /// `Profiles/<key>/`, not as one segment: older installs stored profile
  /// names as typed, so a key may hold a `/` (`Mom/Dad` lives in
  /// `Profiles/Mom/Dad/`).
  static ClipRef? tryParse({
    required ProfileKey profile,
    required String relPath,
  }) {
    final List<String> segments = relPath.split('/');
    if (segments.first.isEmpty || segments.contains('..')) return null;
    final String folder = '${PathNames.profilesFolder}/${profile.value}/';
    final bool inFolder = profile.isDefault
        ? segments.length == 1 ||
              (segments.first != PathNames.profilesFolder &&
                  segments.first != PathNames.moviesFolder)
        : relPath.length > folder.length && relPath.startsWith(folder);
    if (!inFolder) return null;
    final ({LocalDay day, int ordinal})? name = ClipNameCodec.parse(
      segments.last,
    );
    if (name == null) return null;
    return ClipRef._(profile, relPath, name.day, name.ordinal);
  }

  final ProfileKey profile;

  /// Path relative to `AppPaths.videos`, e.g. `2024-01-05.mp4`,
  /// `Profiles/Work/2024-01-05-2.mp4` or `trip/2024-01-05.mp4` (a user-made
  /// sub-folder). The only form ever persisted.
  final String relPath;

  /// The day the file name says (see `ClipNameCodec`).
  final LocalDay day;

  /// 1 for the bare `yyyy-MM-dd.mp4`, N for `yyyy-MM-dd-N.mp4`.
  final int ordinal;

  @override
  List<Object?> get props => <Object?>[profile, relPath];
}
