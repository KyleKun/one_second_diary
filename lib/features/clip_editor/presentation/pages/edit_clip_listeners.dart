import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/logging/bug_report_service.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/features/clip_editor/domain/geotag.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_state.dart';
import 'package:one_second_diary/features/clip_editor/presentation/dialogs/save_failed_dialog.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/settings/presentation/report_error/no_mail_app_snackbar.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';

/// The clip editor's side effects, on the editor's transitions (build
/// stays pure): the pop after a save, the failed-save dialog, the "Typed
/// location removed" snackbar with Undo, "Place saved" (or that it could
/// not be), and a dialog for a location refusal the user met by turning
/// the switch on. A refusal met as the
/// editor opened is only shown on the card, and a plain denial needs
/// nothing more (the system just asked).
class EditClipListeners extends StatelessWidget {
  const EditClipListeners({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: <BlocListener<EditClipCubit, EditClipState>>[
      BlocListener<EditClipCubit, EditClipState>(
        listenWhen: (EditClipState previous, EditClipState current) =>
            previous.geotag.status != current.geotag.status &&
            current.geotag.asked &&
            (current.geotag.status == GeotagStatus.blocked ||
                current.geotag.status == GeotagStatus.serviceOff),
        listener: (BuildContext context, EditClipState state) => unawaited(
          state.geotag.status == GeotagStatus.blocked
              ? _explainBlocked(context)
              : _explainServiceOff(context),
        ),
      ),
      BlocListener<EditClipCubit, EditClipState>(
        listenWhen: (EditClipState previous, EditClipState current) =>
            previous.saveStatus != SaveStatus.saved &&
            current.saveStatus == SaveStatus.saved,
        listener: (BuildContext context, EditClipState state) =>
            Navigator.of(context).pop(state.saved),
      ),
      BlocListener<EditClipCubit, EditClipState>(
        listenWhen: (EditClipState previous, EditClipState current) =>
            previous.saveStatus != SaveStatus.failed &&
            current.saveStatus == SaveStatus.failed,
        listener: (BuildContext context, EditClipState state) => unawaited(
          _explainFailure(
            context,
            state.saveFailure,
            shortfallBytes: state.saveShortfallBytes,
          ),
        ),
      ),
      BlocListener<EditClipCubit, EditClipState>(
        listenWhen: (EditClipState previous, EditClipState current) =>
            previous.geotag.removedTyped == null &&
            current.geotag.removedTyped != null,
        listener: (BuildContext context, EditClipState state) =>
            _offerTypedBack(context, state.geotag.removedTyped!),
      ),
      BlocListener<EditClipCubit, EditClipState>(
        listenWhen: (EditClipState previous, EditClipState current) =>
            previous.placeSaves < current.placeSaves,
        listener: (BuildContext context, _) => OsdSnackbar.show(
          context,
          kind: OsdSnackKind.success,
          title: Strings.placeSaved,
        ),
      ),
      BlocListener<EditClipCubit, EditClipState>(
        listenWhen: (EditClipState previous, EditClipState current) =>
            previous.placeSaveFailures < current.placeSaveFailures,
        listener: (BuildContext context, _) => OsdSnackbar.show(
          context,
          kind: OsdSnackKind.error,
          title: Strings.preferencesSaveFailed,
        ),
      ),
    ],
    child: child,
  );

  static Future<void> _explainFailure(
    BuildContext context,
    SaveFailure failure, {
    required int? shortfallBytes,
  }) async {
    final BugReportService reports = context.read<BugReportService>();
    final BugReportOutcome? outcome = await SaveFailedDialog.show(
      context,
      failure: failure,
      shortfallBytes: shortfallBytes,
      photo: context.read<EditClipCubit>().state.args.source is PhotoSource,
      onReport: () => reports.reportError(body: Strings.errorMailBody),
    );
    if (outcome != BugReportOutcome.noMailApp || !context.mounted) return;
    NoMailAppSnackbar.show(context);
  }

  static Future<void> _explainBlocked(BuildContext context) async {
    final PermissionRequester permissions = context.read<PermissionRequester>();
    final bool open = await OsdConfirmDialog.show(
      context,
      title: Strings.locationOffDialogTitle,
      body: Strings.locationPermissionPermanentlyDenied,
      cancelLabel: Strings.notNow,
      confirmLabel: Strings.openSettings,
    );
    if (open) await permissions.openSettings();
  }

  static Future<void> _explainServiceOff(BuildContext context) =>
      showOsdDialog<void>(
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

  static void _offerTypedBack(BuildContext context, String typed) {
    final EditClipCubit editor = context.read<EditClipCubit>();
    OsdSnackbar.show(
      context,
      kind: OsdSnackKind.info,
      title: Strings.saveVideoTypedLocationRemoved,
      actionLabel: Strings.commonUndo,
      onAction: () async {
        if (!editor.isClosed) editor.typedPlaceChanged(typed);
      },
    );
  }
}
