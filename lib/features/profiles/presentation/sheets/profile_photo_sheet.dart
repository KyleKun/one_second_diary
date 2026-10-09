import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_action_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// What the photo sheet offers.
enum ProfilePhotoChoice {
  gallery,

  camera,

  /// Only offered while there is a photo.
  remove,
}

/// The profile photo sheet: "Choose from gallery", "Take a photo" and, while
/// there is a photo, "Remove photo". It stacks on the profile sheet that
/// opened it and gives back the choice, or null when dismissed.
class ProfilePhotoSheet extends StatelessWidget {
  const ProfilePhotoSheet({super.key, required this.canRemove});

  static Key rowKey(ProfilePhotoChoice choice) =>
      ValueKey<String>('profilePhotoSheet.${choice.name}');

  /// Whether "Remove photo" shows.
  final bool canRemove;

  /// Opens the sheet over [context]'s sheet.
  static Future<ProfilePhotoChoice?> show(
    BuildContext context, {
    required bool canRemove,
  }) => showOsdSheet<ProfilePhotoChoice>(
    context,
    title: Strings.profilePhotoTitle,
    child: ProfilePhotoSheet(canRemove: canRemove),
  );

  @override
  Widget build(BuildContext context) {
    void pick(ProfilePhotoChoice choice) => Navigator.of(context).pop(choice);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.s8,
      children: <Widget>[
        OsdActionRow(
          key: rowKey(ProfilePhotoChoice.gallery),
          icon: OsdIcons.photoLibrary,
          label: Strings.profilePhotoChoose,
          onTap: () => pick(ProfilePhotoChoice.gallery),
        ),
        OsdActionRow(
          key: rowKey(ProfilePhotoChoice.camera),
          icon: OsdIcons.photoCamera,
          label: Strings.profilePhotoTake,
          onTap: () => pick(ProfilePhotoChoice.camera),
        ),
        if (canRemove)
          OsdActionRow(
            key: rowKey(ProfilePhotoChoice.remove),
            icon: OsdIcons.delete,
            label: Strings.profilePhotoRemove,
            tone: OsdActionRowTone.destructive,
            onTap: () => pick(ProfilePhotoChoice.remove),
          ),
      ],
    );
  }
}
