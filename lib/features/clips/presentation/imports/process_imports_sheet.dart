import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/data/import_processor.dart';
import 'package:one_second_diary/features/clips/domain/imported_video.dart';
import 'package:one_second_diary/features/clips/presentation/imports/import_labels.dart';
import 'package:one_second_diary/features/clips/presentation/imports/process_import_flow.dart';
import 'package:one_second_diary/features/clips/presentation/imports/process_imports_cubit.dart';
import 'package:one_second_diary/features/clips/presentation/imports/process_imports_state.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/shared/widgets/buttons/destructive_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/progress/osd_progress_bar.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_radio_row.dart';
import 'package:one_second_diary/shared/widgets/surfaces/section_label.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The processing sheet: what was found per profile, the remembered length
/// and date-stamp choices, the Originals folder size with "Delete originals",
/// and "Process N videos", which runs them one by one and can be cancelled.
/// It makes its own [ProcessImportsCubit] from the context's [ImportProcessor].
class ProcessImportsSheet extends StatelessWidget {
  const ProcessImportsSheet({super.key});

  static const Key bodyKey = Key('processImportsSheet.body');
  static const Key startKey = Key('processImportsSheet.start');
  static const Key stopKey = Key('processImportsSheet.stop');
  static const Key progressKey = Key('processImportsSheet.progress');
  static const Key keepFirstKey = Key('processImportsSheet.keepFirst');
  static const Key keepWholeKey = Key('processImportsSheet.keepWhole');
  static const Key dateStampKey = Key('processImportsSheet.dateStamp');
  static const Key resultKey = Key('processImportsSheet.result');
  static const Key deleteOriginalsKey = Key(
    'processImportsSheet.deleteOriginals',
  );

  /// Shows the sheet for [profiles], in the app's order.
  static Future<void> show(
    BuildContext context, {
    required List<ProfileKey> profiles,
  }) => showOsdSheet<void>(
    context,
    title: Strings.processImportsTitle,
    height: OsdSheetHeight.tall,
    child: BlocProvider<ProcessImportsCubit>(
      create: (BuildContext context) {
        final ProcessImportsCubit cubit = ProcessImportsCubit(
          processor: context.read<ImportProcessor>(),
        );
        unawaited(cubit.load(profiles));
        return cubit;
      },
      child: const ProcessImportsSheet(key: bodyKey),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ProcessImportsState state = context
        .watch<ProcessImportsCubit>()
        .state;
    final bool running = state.stage == ProcessImportsStage.running;
    OsdSheetRoute.setBusy(context, busy: running);
    // A tall sheet expects a body that scrolls on its own.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ImportedProfileSummary line in state.perProfile)
            OsdListRow(
              title: Strings.processImportsProfile(
                profile: _nameOf(context, line.profile),
                videos: Strings.importedVideoCount(
                  line.count,
                  format: ImportLabels.numberFormat(context),
                ),
                length: ImportLabels.roughDuration(
                  Duration(milliseconds: line.durationMs),
                ),
              ),
              icon: OsdIcons.videoLibrary,
            ),
          if (state.stage == ProcessImportsStage.listing)
            const Padding(
              padding: EdgeInsets.all(OsdSpace.s16),
              child: OsdProgressBar(value: 0),
            ),
          if (state.stage == ProcessImportsStage.ready ||
              state.stage == ProcessImportsStage.listing) ...<Widget>[
            SectionLabel.soft(label: Strings.processImportsLength),
            OsdRadioRow(
              key: keepFirstKey,
              label: Strings.processImportsKeepFirst(
                length: ImportLabels.seconds(state.choices.quickCutMs),
              ),
              selected: !state.choices.keepWhole,
              onSelected: () => unawaited(
                context.read<ProcessImportsCubit>().setKeepWhole(
                  keepWhole: false,
                ),
              ),
            ),
            const OsdDivider(),
            OsdRadioRow(
              key: keepWholeKey,
              label: Strings.processImportsKeepWhole,
              selected: state.choices.keepWhole,
              onSelected: () => unawaited(
                context.read<ProcessImportsCubit>().setKeepWhole(
                  keepWhole: true,
                ),
              ),
            ),
            const OsdDivider(),
            OsdListRow(
              key: dateStampKey,
              title: Strings.processImportsDateStamp,
              trailing: OsdRowTrailing.custom(
                OsdSwitch(value: state.choices.dateStamp, interactive: false),
              ),
              toggled: state.choices.dateStamp,
              onTap: () => unawaited(
                context.read<ProcessImportsCubit>().setDateStamp(
                  dateStamp: !state.choices.dateStamp,
                ),
              ),
            ),
          ],
          if (running) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OsdSpace.textInset,
                OsdSpace.s16,
                OsdSpace.textInset,
                OsdSpace.s8,
              ),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  Strings.processImportsProgress(
                    done: ImportLabels.numberFormat(context).format(state.done),
                    total: ImportLabels.numberFormat(
                      context,
                    ).format(state.total),
                  ),
                  key: progressKey,
                  style: context.typography.titleSmall.copyWith(
                    color: context.colors.tx,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OsdSpace.textInset,
              ),
              child: OsdProgressBar(
                value: state.total == 0
                    ? 0
                    : (state.done + state.fraction) / state.total,
              ),
            ),
          ],
          if (state.report case final ImportReport report)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OsdSpace.textInset,
                OsdSpace.s16,
                OsdSpace.textInset,
                0,
              ),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _resultOf(context, report),
                  key: resultKey,
                  style: context.typography.body15.copyWith(
                    color: context.colors.tx,
                  ),
                ),
              ),
            ),
          if (state.originalsBytes > 0)
            OsdListRow(
              title: Strings.originalsSize(
                size: ImportLabels.size(context, state.originalsBytes),
              ),
              trailing: OsdRowTrailing.custom(
                DestructiveButton(
                  key: deleteOriginalsKey,
                  label: Strings.deleteOriginals,
                  hug: true,
                  onPressed: running
                      ? null
                      : () => unawaited(_deleteOriginals(context)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OsdSpace.pageGutter,
              OsdSpace.s16,
              OsdSpace.pageGutter,
              OsdSpace.s8,
            ),
            child: running
                ? NeutralButton(
                    key: stopKey,
                    label: Strings.processImportsStop,
                    onPressed: () =>
                        context.read<ProcessImportsCubit>().cancel(),
                  )
                : PrimaryButton(
                    key: startKey,
                    label: Strings.processImportsStart(
                      state.total,
                      format: ImportLabels.numberFormat(context),
                    ),
                    onPressed: state.canStart
                        ? () => unawaited(
                            context.read<ProcessImportsCubit>().start(
                              stampText: ProcessImportFlow.stampTextOf(context),
                            ),
                          )
                        : null,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOriginals(BuildContext context) async {
    final ProcessImportsCubit cubit = context.read<ProcessImportsCubit>();
    final bool confirmed = await OsdConfirmDialog.show(
      context,
      title: Strings.deleteOriginalsTitle,
      body: Strings.deleteOriginalsBody(
        size: ImportLabels.size(context, cubit.state.originalsBytes),
      ),
      cancelLabel: Strings.notNow,
      confirmLabel: Strings.deleteOriginals,
      destructive: true,
    );
    if (confirmed) await cubit.deleteOriginals();
  }

  static String _resultOf(BuildContext context, ImportReport report) {
    if (report.moveRefused) return Strings.processImportsMoveRefused;
    final String done = Strings.processImportsDone(
      report.processed.length,
      format: ImportLabels.numberFormat(context),
    );
    if (report.skipped.isEmpty) return done;
    return '$done\n${Strings.processImportsSkipped(report.skipped.length, format: ImportLabels.numberFormat(context))}';
  }

  static String _nameOf(BuildContext context, ProfileKey key) =>
      context
          .read<ProfilesCubit>()
          .state
          .profiles
          .where((Profile profile) => profile.key == key)
          .firstOrNull
          ?.displayName ??
      key.albumLabel;
}
