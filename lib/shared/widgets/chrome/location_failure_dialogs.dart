import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/location/location_result.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog.dart';

/// Explains a fix that failed: a dialog for a permission that can only be
/// granted in Settings or the location service off (answers null), else
/// the line to show under the control that asked for the fix.
Future<String?> explainLocationFailure(
  BuildContext context,
  LocationFailure failure,
) async {
  switch (failure) {
    case LocationFailure.permissionBlocked:
      final PermissionRequester permissions = context
          .read<PermissionRequester>();
      final bool open = await OsdConfirmDialog.show(
        context,
        title: Strings.locationOffDialogTitle,
        body: Strings.locationPermissionPermanentlyDenied,
        cancelLabel: Strings.notNow,
        confirmLabel: Strings.openSettings,
      );
      if (open) await permissions.openSettings();
      return null;
    case LocationFailure.serviceDisabled:
      await showOsdDialog<void>(
        context,
        builder: (BuildContext context) => OsdDialog(
          title: Strings.locationOffDialogTitle,
          body: Strings.locationServicesDisabled,
          actions: NeutralButton(
            label: Strings.ok,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      );
      return null;
    case LocationFailure.permissionDenied:
      return Strings.saveVideoLocationAllow;
    case LocationFailure.noPosition || LocationFailure.offline:
      return Strings.placeLocationUnavailable;
  }
}
