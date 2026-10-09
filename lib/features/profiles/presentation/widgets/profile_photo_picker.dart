import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_target.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/profile_photo_sheet.dart';
import 'package:one_second_diary/shared/widgets/identity/avatar_picker.dart';

/// The photo of the profile sheets (`AvatarPicker`): the photo just picked,
/// else the stored one, else the name's initial (an existing profile) or
/// the dashed placeholder (a new one). A tap opens the photo sheet on top.
class ProfilePhotoPicker extends StatelessWidget {
  const ProfilePhotoPicker({super.key});

  /// The picker (the photo and its caption, one button).
  static const Key pickerKey = Key('profilePhotoPicker.picker');

  Future<void> _open(BuildContext context, {required bool hasPhoto}) async {
    final ProfileFormCubit form = context.read<ProfileFormCubit>();
    final ProfilePhotoChoice? choice = await ProfilePhotoSheet.show(
      context,
      canRemove: hasPhoto,
    );
    switch (choice) {
      case null:
        return;
      case ProfilePhotoChoice.gallery:
        await form.pickPhoto(PhotoOrigin.gallery);
      case ProfilePhotoChoice.camera:
        await form.pickPhoto(PhotoOrigin.camera);
      case ProfilePhotoChoice.remove:
        form.removePhoto();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ({String name, String? picked, String? stored, bool isNew, bool busy})
    photo = context.select(
      (ProfileFormCubit cubit) => (
        name: cubit.state.name,
        picked: cubit.state.pickedPhoto,
        stored: cubit.state.photoRemoved ? null : cubit.state.storedPhoto,
        isNew: cubit.state.target is NewProfileForm,
        busy: cubit.state.isBusy,
      ),
    );
    final String? picked = photo.picked;
    final String? stored = photo.stored;
    final ImageProvider? image = picked != null
        ? FileImage(File(picked))
        : stored != null
        ? FileImage(File(context.read<AppPaths>().absoluteFromInternal(stored)))
        : null;
    final bool hasPhoto = image != null;
    final VoidCallback? open = photo.busy
        ? null
        : () => unawaited(_open(context, hasPhoto: hasPhoto));
    return Center(
      child: KeyedSubtree(
        key: pickerKey,
        child: photo.isNew && !hasPhoto
            ? AvatarPicker.placeholder(
                caption: Strings.profileAddPhotoOptional,
                onPressed: open,
              )
            : AvatarPicker(
                name: photo.name,
                photo: image,
                caption: hasPhoto
                    ? Strings.profileChangePhoto
                    : Strings.profileAddPhoto,
                compactCaption: photo.isNew,
                onPressed: open,
              ),
      ),
    );
  }
}
