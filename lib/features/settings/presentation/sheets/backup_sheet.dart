import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/features/clips/presentation/imports/import_labels.dart';
import 'package:one_second_diary/features/clips/presentation/imports/process_import_flow.dart';
import 'package:one_second_diary/features/settings/domain/backup_steps.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/backup_sheet_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/backup_sheet_state.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_action_row.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_step_row.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The Backup & restore sheet: first a choice
/// (save my videos somewhere safe, or bring videos into the app), then the
/// numbered, platform-specific steps with the phone's real folder path,
/// "Open in Files" (iOS), "Copy path" (Android), "Look for new videos"
/// (import), the Android video link, and the Originals note. The sheet's
/// own back returns to the choice.
///
/// Open it with [show]; the page's route provides the [BackupSheetCubit].
class BackupSheet extends StatelessWidget {
  const BackupSheet({super.key});

  static const Key bodyKey = Key('backupSheet.body');
  static const Key saveChoiceKey = Key('backupSheet.save');
  static const Key bringInChoiceKey = Key('backupSheet.bringIn');
  static const Key backKey = Key('backupSheet.back');
  static const Key resultKey = Key('backupSheet.result');
  static const Key watchVideoKey = Key('backupSheet.watchVideo');

  /// The step at 1-based [number].
  static Key stepKey(int number) =>
      ValueKey<String>('backupSheet.step.$number');

  /// Shows the sheet over [context], which must provide a
  /// [BackupSheetCubit].
  static Future<void> show(BuildContext context) async {
    final BackupSheetCubit cubit = context.read<BackupSheetCubit>();
    await showOsdSheet<void>(
      context,
      title: Strings.backupRestore,
      titleIcon: OsdIcons.backup,
      height: OsdSheetHeight.tall,
      child: BlocProvider<BackupSheetCubit>.value(
        value: cubit,
        child: const BackupSheet(key: bodyKey),
      ),
    );
    // A scan that found anything leads into the processing sheet: the
    // page under it prompts "N imported videos · Process" once it closes.
    if (!context.mounted) return;
    if ((cubit.state.found?.total ?? 0) > 0) {
      ProcessImportFlow.promptIfAny(context);
    }
    cubit.back();
  }

  @override
  Widget build(BuildContext context) {
    final BackupSheetState state = context.watch<BackupSheetCubit>().state;
    // A tall sheet keeps its handle and title fixed and expects the body to
    // scroll on its own: the numbered steps outgrow a phone.
    return SingleChildScrollView(
      child: state.stage == BackupSheetStage.choice
          ? const _Choice()
          : _Steps(state: state),
    );
  }
}

/// "What do you want to do?" and the two tiles.
class _Choice extends StatelessWidget {
  const _Choice();

  @override
  Widget build(BuildContext context) {
    final BackupSheetCubit cubit = context.read<BackupSheetCubit>();
    final bool ios = cubit.state.platform == BackupPlatform.ios;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OsdSpace.textInset,
            OsdSpace.s4,
            OsdSpace.textInset,
            OsdSpace.s12,
          ),
          child: Text(
            Strings.backupChoiceTitle,
            style: context.typography.titleSmall.copyWith(
              color: context.colors.tx,
            ),
          ),
        ),
        OsdActionRow(
          key: BackupSheet.saveChoiceKey,
          icon: OsdIcons.backup,
          label: Strings.backupChoiceSave,
          tone: OsdActionRowTone.primary,
          onTap: () => unawaited(cubit.choose(BackupMode.backUp)),
        ),
        OsdActionRow(
          key: BackupSheet.bringInChoiceKey,
          icon: OsdIcons.videoLibrary,
          label: Strings.backupChoiceBringIn,
          onTap: () => unawaited(cubit.choose(BackupMode.bringIn)),
        ),
        if (ios)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OsdSpace.textInset,
              OsdSpace.s12,
              OsdSpace.textInset,
              OsdSpace.s8,
            ),
            child: Text(
              Strings.iosBackupWarning,
              style: context.typography.footnote.copyWith(
                color: context.colors.d2,
              ),
            ),
          ),
      ],
    );
  }
}

/// The numbered steps of the chosen mode, with their buttons.
class _Steps extends StatelessWidget {
  const _Steps({required this.state});

  final BackupSheetState state;

  @override
  Widget build(BuildContext context) {
    final BackupSheetCubit cubit = context.read<BackupSheetCubit>();
    final String path = cubit.folderPath;
    final bool scanning = state.stage == BackupSheetStage.scanning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OsdTextButton(
            key: BackupSheet.backKey,
            label: Strings.backupChoiceTitle,
            icon: OsdIcons.arrowBack,
            hug: true,
            onPressed: cubit.back,
          ),
        ),
        for (final (int index, BackupStep step) in state.steps.indexed)
          OsdStepRow(
            key: BackupSheet.stepKey(index + 1),
            number: index + 1,
            text: _textOf(step.text, path: path),
            actionLabel: _actionLabel(step.action),
            actionLoading:
                scanning && step.action == BackupStepAction.lookForNewVideos,
            onAction: step.action == null || scanning
                ? null
                : () => unawaited(_act(context, step.action!)),
            note: _noteOf(context, step.action),
          ),
        if (state.mode == BackupMode.bringIn)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OsdSpace.textInset,
              OsdSpace.s8,
              OsdSpace.textInset,
              OsdSpace.s8,
            ),
            child: Text(
              state.originalsBytes > 0
                  ? '${Strings.backupOriginalsNote} '
                        '${Strings.originalsSize(size: ImportLabels.size(context, state.originalsBytes))}'
                  : Strings.backupOriginalsNote,
              style: context.typography.footnote.copyWith(
                color: context.colors.mu,
              ),
            ),
          ),
        if (state.showsVideoLink)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: OsdSpace.s12),
              child: OsdTextButton(
                key: BackupSheet.watchVideoKey,
                label: Strings.backupWatchVideo,
                icon: OsdIcons.playArrow,
                hug: true,
                onPressed: () => unawaited(cubit.watchVideo()),
              ),
            ),
          ),
        const SizedBox(height: OsdSpace.s12),
      ],
    );
  }

  Future<void> _act(BuildContext context, BackupStepAction action) async {
    final BackupSheetCubit cubit = context.read<BackupSheetCubit>();
    switch (action) {
      case BackupStepAction.openInFiles:
        await cubit.openInFiles();
      case BackupStepAction.copyPath:
        await Clipboard.setData(ClipboardData(text: cubit.folderPath));
        if (!context.mounted) return;
        OsdSnackbar.show(
          context,
          kind: OsdSnackKind.success,
          title: Strings.backupPathCopied,
        );
      case BackupStepAction.lookForNewVideos:
        await cubit.lookForNewVideos();
    }
  }

  String _textOf(BackupStepText text, {required String path}) => switch (text) {
    BackupStepText.androidBackup1 => Strings.backupAndroidStep1(path: path),
    BackupStepText.androidBackup2 => Strings.backupAndroidStep2,
    BackupStepText.androidBackup3 => Strings.backupAndroidStep3,
    BackupStepText.androidBackup4 => Strings.backupAndroidStep4,
    BackupStepText.androidBackup5 => Strings.backupAndroidStep5,
    BackupStepText.iosBackup1 => Strings.backupIosStep1,
    BackupStepText.iosBackup2 => Strings.backupIosStep2,
    BackupStepText.iosBackup3 => Strings.backupIosStep3,
    BackupStepText.iosBackup4 => Strings.backupIosStep4,
    BackupStepText.androidImport1 => Strings.importAndroidStep1(path: path),
    BackupStepText.iosImport1 => Strings.importIosStep1,
    BackupStepText.importDateNamed => Strings.importStepDateNamed,
    BackupStepText.importLook => Strings.importStepLook,
    BackupStepText.importProcessed => Strings.importStepProcessed,
  };

  static String? _actionLabel(BackupStepAction? action) => switch (action) {
    null => null,
    BackupStepAction.openInFiles => Strings.backupOpenInFiles,
    BackupStepAction.copyPath => Strings.backupCopyPath,
    BackupStepAction.lookForNewVideos => Strings.backupLookForNewVideos,
  };

  /// The line under a step: the fallback when the Files app would not
  /// open, or the scan's answer (a live region through the row).
  String? _noteOf(BuildContext context, BackupStepAction? action) =>
      switch (action) {
        BackupStepAction.openInFiles when state.openInFilesFailed =>
          Strings.backupOpenInFilesFallback,
        BackupStepAction.lookForNewVideos
            when state.stage == BackupSheetStage.scanning =>
          Strings.backupLooking,
        BackupStepAction.lookForNewVideos when state.found != null =>
          state.found!.total == 0
              ? Strings.backupNothingNew(
                  folder: PathNames.fileNameOf(
                    context.read<BackupSheetCubit>().folderPath,
                  ),
                )
              : Strings.backupFoundClips(
                  state.found!.total,
                  format: ImportLabels.numberFormat(context),
                ),
        _ => null,
      };
}
