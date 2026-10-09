import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/permissions/access_outcome.dart';
import 'package:one_second_diary/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:one_second_diary/features/settings/presentation/report_error/report_error_cubit.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/surfaces/camera_state_panel.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// The panels over the preview: access (camera and microphone needed;
/// "Allow access", or "Open settings" after a permanent refusal) and error
/// (the camera couldn't start; "Try again", "Use phone's camera app",
/// "Report error"). Nothing otherwise. It rebuilds only when the panel
/// changes.
class CameraStateOverlay extends StatelessWidget {
  const CameraStateOverlay({super.key});

  static const Key accessKey = Key('cameraStateOverlay.access');
  static const Key errorKey = Key('cameraStateOverlay.error');
  static const Key reportKey = Key('cameraStateOverlay.report');

  @override
  Widget build(BuildContext context) {
    final (
      RecordingStatus status,
      AccessOutcome? access,
      bool systemCamera,
    ) = context.select(
      (RecordingBloc bloc) =>
          (bloc.state.status, bloc.state.access, bloc.state.systemCamera),
    );
    final Widget? panel = switch (status) {
      RecordingStatus.needsPermission => CameraStatePanel(
        key: accessKey,
        icon: OsdIcons.videocamOff,
        title: systemCamera
            ? Strings.cameraPermissionTitle
            : Strings.cameraMicPermissionTitle,
        body: systemCamera
            ? Strings.cameraPermissionDesc
            : Strings.cameraMicPermissionDesc,
        actionLabel: access == AccessOutcome.blocked
            ? Strings.openSettings
            : Strings.allowAccess,
        onAction: () => context.read<RecordingBloc>().add(
          access == AccessOutcome.blocked
              ? const RecordingSettingsOpened()
              : const RecordingAccessRequested(),
        ),
      ),
      RecordingStatus.failed => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CameraStatePanel(
            key: errorKey,
            icon: OsdIcons.noPhotography,
            title: Strings.cameraErrorTitle,
            body: Strings.cameraErrorBody,
            actionLabel: Strings.commonTryAgain,
            onAction: () =>
                context.read<RecordingBloc>().add(const RecordingRetried()),
            secondaryLabel: systemCamera ? null : Strings.cameraErrorUseNative,
            onSecondary: systemCamera
                ? null
                : () => context.read<RecordingBloc>().add(
                    const RecordingSystemCameraRequested(),
                  ),
          ),
          const _ReportError(key: reportKey),
        ],
      ),
      _ => null,
    };
    if (panel == null) return const SizedBox.shrink();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: OsdSpace.s24),
        child: panel,
      ),
    );
  }
}

/// "Report error" under the error panel: the mail app opens with the logs;
/// off while it is being opened.
class _ReportError extends StatelessWidget {
  const _ReportError({super.key});

  @override
  Widget build(BuildContext context) {
    final bool sending = context.select(
      (ReportErrorCubit report) => report.state == ReportErrorStatus.sending,
    );
    return OsdTextButton(
      label: Strings.reportError,
      tone: OsdTextButtonTone.muted,
      onPressed: sending
          ? null
          : () => unawaited(
              context.read<ReportErrorCubit>().report(
                body: Strings.errorMailBody,
              ),
            ),
    );
  }
}
