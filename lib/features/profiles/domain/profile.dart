import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// A diary profile: its own clip folder, canvas and format.
final class Profile extends Equatable {
  /// [format] is the profile's write-once clip format; left out, it is
  /// [ClipFormat.legacy] on [orientation].
  const Profile({
    required this.key,
    required this.displayName,
    required this.orientation,
    required this.avatarRelPath,
    this._format,
  });

  /// Immutable identity and folder name (`''` for Default).
  final ProfileKey key;

  /// The name shown in the app. Renaming changes only this, never [key];
  /// it may use any Unicode.
  final String displayName;

  /// The canvas, fixed when the profile was created.
  final VideoOrientation orientation;

  /// Profile photo, relative to `AppPaths.internal` (e.g.
  /// `avatars/Work.jpg`); null when there is none.
  final String? avatarRelPath;

  final ClipFormat? _format;

  /// The format of every clip of this profile, fixed when it was created
  /// (`clipFormat_<key>`); [ClipFormat.legacy] on [orientation] when none
  /// is stored. Movies are stream-copy joins, so it never changes: another
  /// quality means a new profile (`ProfileConversionStarter`).
  ClipFormat get format => _format ?? ClipFormat.legacy(orientation);

  /// Default is decided by identity (the empty key), never by its name.
  bool get isDefault => key.isDefault;

  @override
  List<Object?> get props => <Object?>[
    key,
    displayName,
    orientation,
    avatarRelPath,
    format,
  ];
}
