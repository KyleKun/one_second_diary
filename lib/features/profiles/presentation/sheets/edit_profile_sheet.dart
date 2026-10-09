import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_state.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_target.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/locked_orientation_row.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/locked_quality_row.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_form_listener.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_name_field.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_photo_picker.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_loading_delay.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_spinner.dart';
import 'package:one_second_diary/shared/widgets/foundation/snackbar_anchor.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// The body of the "Edit profile" sheet: photo, name, locked orientation,
/// locked quality with "Convert into a new profile…", Save and, except for
/// Default, "Delete profile".
///
/// Delete asks first, then deletes the profile and its clips and closes with
/// what the phone kept. "Convert…" closes with a [ConvertProfileRequest]: the
/// opener shows the converter's sheet (sheets don't stack). Open it with
/// `ProfileSheets.showEdit`.
class EditProfileSheet extends StatelessWidget {
  const EditProfileSheet({super.key});

  static const Key saveKey = Key('editProfileSheet.save');

  static const Key deleteKey = Key('editProfileSheet.delete');

  static const Key convertKey = Key('editProfileSheet.convert');

  @override
  Widget build(BuildContext context) {
    final (
      VideoOrientation orientation,
      ClipFormat format,
      bool canDelete,
    ) = context.select(
      (ProfileFormCubit cubit) => (
        cubit.state.orientation!,
        cubit.state.format!,
        cubit.state.canDelete,
      ),
    );
    return OsdSnackbarHost(
      child: ProfileFormListener(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: OsdSpace.sheetGap,
          children: <Widget>[
            const ProfilePhotoPicker(),
            const ProfileNameField(),
            LockedOrientationRow(orientation: orientation),
            LockedQualityRow(format: format),
            const _ConvertButton(),
            const _SaveButton(),
            if (canDelete) const _DeleteButton(),
          ],
        ),
      ),
    );
  }
}

/// What "Edit profile" closes with when the user asks to convert the
/// profile into a new one.
final class ConvertProfileRequest {
  const ConvertProfileRequest(this.profile);

  final ProfileKey profile;
}

/// "Convert into a new profile…": closes the sheet with the request.
class _ConvertButton extends StatelessWidget {
  const _ConvertButton();

  @override
  Widget build(BuildContext context) {
    final bool busy = context.select(
      (ProfileFormCubit cubit) => cubit.state.isBusy,
    );
    return OsdTextButton(
      key: EditProfileSheet.convertKey,
      label: Strings.convertIntoNewProfile,
      icon: OsdIcons.movie,
      tone: OsdTextButtonTone.secondary,
      onPressed: busy
          ? null
          : () {
              final ProfileFormTarget target = context
                  .read<ProfileFormCubit>()
                  .state
                  .target;
              if (target is EditProfileForm) {
                Navigator.of(
                  context,
                ).pop(ConvertProfileRequest(target.profile));
              }
            },
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton();

  @override
  Widget build(BuildContext context) {
    final (bool canSave, bool saving) = context.select(
      (ProfileFormCubit cubit) =>
          (cubit.state.canSave, cubit.state.status == ProfileFormStatus.saving),
    );
    return SnackbarAnchor(
      gap: OsdSpace.snackbarAboveCta,
      child: PrimaryButton(
        key: EditProfileSheet.saveKey,
        label: Strings.save,
        haptic: OsdHaptic.light,
        loading: saving,
        onPressed: canSave
            ? () => unawaited(context.read<ProfileFormCubit>().save())
            : null,
      ),
    );
  }
}

/// "Delete profile": the confirmation names the profile; confirmed, the
/// form deletes it. While it deletes (the phone may ask for consent for
/// each clip a previous install made), a spinner takes the button's place
/// after a short delay.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton();

  static const double _height = 40;

  Future<void> _confirm(BuildContext context) async {
    final ProfileFormCubit form = context.read<ProfileFormCubit>();
    final CommonLabels labels = CommonLabels.of(context);
    final bool confirmed = await OsdConfirmDialog.show(
      context,
      title: Strings.profileDeleteDialogTitle(name: form.state.originalName),
      body: Strings.deleteProfileTooltip,
      cancelLabel: labels.cancel,
      confirmLabel: labels.delete,
      destructive: true,
      badgeIcon: OsdIcons.delete,
    );
    if (confirmed) await form.delete();
  }

  @override
  Widget build(BuildContext context) {
    final (bool busy, bool deleting) = context.select(
      (ProfileFormCubit cubit) => (
        cubit.state.isBusy,
        cubit.state.status == ProfileFormStatus.deleting,
      ),
    );
    return OsdLoadingDelay(
      loading: deleting,
      builder: (BuildContext context, bool showLoading) => showLoading
          ? SizedBox(
              height: _height,
              child: Center(child: OsdSpinner(color: context.colors.red)),
            )
          : OsdTextButton(
              key: EditProfileSheet.deleteKey,
              label: Strings.deleteProfile,
              icon: OsdIcons.delete,
              tone: OsdTextButtonTone.destructive,
              height: _height,
              onPressed: busy ? null : () => unawaited(_confirm(context)),
            ),
    );
  }
}
