import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_state.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// What a profile sheet does when its form changes status, so the sheets'
/// `build` stays pure.
///
/// - While storing or deleting, the sheet can't be dismissed.
/// - Stored: it closes, with the new profile if it made one; deleted: with
///   what the phone kept.
/// - A refused photo: the permission dialog, or "This file can't be used".
/// - A refused save or delete: a snackbar in the sheet, which stays open.
///
/// Place it under the sheet's `OsdSnackbarHost`.
class ProfileFormListener extends StatelessWidget {
  const ProfileFormListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocListener<ProfileFormCubit, ProfileFormState>(
        listenWhen: (ProfileFormState previous, ProfileFormState current) =>
            previous.status != current.status,
        listener: _statusChanged,
        child: child,
      );

  static void _statusChanged(BuildContext context, ProfileFormState state) {
    OsdSheetRoute.setBusy(context, busy: state.isBusy);
    switch (state.status) {
      case ProfileFormStatus.saved:
        Navigator.of(context).pop(state.created);
      case ProfileFormStatus.deleted:
        Navigator.of(context).pop(state.deletion);
      case ProfileFormStatus.photoDenied:
        unawaited(_explainDenied(context, state.deniedOrigin));
      case ProfileFormStatus.photoUnavailable:
        _snack(context, Strings.importFailed);
      case ProfileFormStatus.saveFailed:
        _snack(context, Strings.profileSaveFailed);
      case ProfileFormStatus.deleteFailed:
        _snack(context, Strings.profileDeleteFailed);
      case ProfileFormStatus.editing ||
          ProfileFormStatus.pickingPhoto ||
          ProfileFormStatus.saving ||
          ProfileFormStatus.deleting:
        break;
    }
  }

  static Future<void> _explainDenied(
    BuildContext context,
    PhotoOrigin? origin,
  ) async {
    final PermissionRequester permissions = context.read<PermissionRequester>();
    final bool open = await OsdConfirmDialog.show(
      context,
      title: origin == PhotoOrigin.camera
          ? Strings.cameraPermissionTitle
          : Strings.storagePermissionTitle,
      body: Strings.permissionSettingsHint,
      cancelLabel: Strings.notNow,
      confirmLabel: Strings.openSettings,
      badgeIcon: origin == PhotoOrigin.camera
          ? OsdIcons.photoCamera
          : OsdIcons.photoLibrary,
    );
    if (open) await permissions.openSettings();
  }

  static void _snack(BuildContext context, String title) =>
      OsdSnackbar.show(context, kind: OsdSnackKind.error, title: title);
}
