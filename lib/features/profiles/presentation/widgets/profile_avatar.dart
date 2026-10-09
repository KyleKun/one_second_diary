import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/shared/widgets/identity/osd_avatar.dart';

/// A profile's [OsdAvatar]: its photo when it has one, else its initial.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, required this.size});

  final Profile profile;

  /// The diameter.
  final double size;

  /// The photo of [profile], read from the app's private folder; null when
  /// it has none. For widgets that take an `ImageProvider` (`ProfileChip`,
  /// `ProfileOptionTile`, `ProfileTile`).
  static ImageProvider? photoOf(BuildContext context, Profile profile) {
    final String? photo = profile.avatarRelPath;
    if (photo == null) return null;
    return FileImage(
      File(context.read<AppPaths>().absoluteFromInternal(photo)),
    );
  }

  @override
  Widget build(BuildContext context) => OsdAvatar(
    name: profile.displayName,
    photo: photoOf(context, profile),
    size: size,
  );
}
