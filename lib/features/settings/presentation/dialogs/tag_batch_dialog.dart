import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/tags_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/tags_state.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog.dart';
import 'package:one_second_diary/shared/widgets/progress/osd_progress_bar.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The progress of a tag batch (Settings › Tags): "Rename tag" or "Remove
/// tag", a bar, "Updating 3 of 12…" (a live region) and Stop, which stops
/// the batch after the clip in flight. Nothing dismisses it; it closes
/// itself once the batch has finished, and the page then says the outcome.
///
/// Open it with [show] on the page's `TagsCubit`, as the page does when
/// a batch starts. A batch over no clips can end before the dialog is
/// built: it then closes right after its first frame.
class TagBatchDialog extends StatefulWidget {
  const TagBatchDialog({super.key});

  static const Key bodyKey = Key('tagBatchDialog.body');

  static const Key progressKey = Key('tagBatchDialog.progress');

  static const Key stopKey = Key('tagBatchDialog.stop');

  /// Opens the dialog over the whole app on [cubit]; completes once the
  /// batch has finished and the dialog closed.
  static Future<void> show(BuildContext context, {required TagsCubit cubit}) =>
      showOsdDialog<void>(
        context,
        dismissible: false,
        builder: (_) => BlocProvider<TagsCubit>.value(
          value: cubit,
          child: const TagBatchDialog(key: bodyKey),
        ),
      );

  @override
  State<TagBatchDialog> createState() => _TagBatchDialogState();
}

class _TagBatchDialogState extends State<TagBatchDialog> {
  @override
  void initState() {
    super.initState();
    // The listener below only hears what changes after it subscribes.
    if (!context.read<TagsCubit>().state.isBatchRunning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final TagBatchRun? run = context.select(
      (TagsCubit cubit) => cubit.state.batch,
    );
    final TagBatchKind kind = run?.kind ?? TagBatchKind.rename;
    final int done = run?.done ?? 0;
    final int total = run?.total ?? 0;
    return BlocListener<TagsCubit, TagsState>(
      listenWhen: (TagsState previous, TagsState current) =>
          previous.isBatchRunning && !current.isBatchRunning,
      listener: (BuildContext context, _) => Navigator.of(context).pop(),
      child: PopScope(
        canPop: false,
        child: OsdDialog(
          title: switch (kind) {
            TagBatchKind.rename => Strings.renameTag,
            TagBatchKind.remove => Strings.removeTag,
          },
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: OsdSpace.dialogGap,
            children: <Widget>[
              OsdProgressBar(
                key: TagBatchDialog.progressKey,
                value: run?.progress ?? 0,
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  Strings.tagBatchProgress(done: done, total: total),
                  style: typography.body14.copyWith(color: colors.sub),
                ),
              ),
            ],
          ),
          actions: NeutralButton(
            key: TagBatchDialog.stopKey,
            label: Strings.makingMovieStop,
            onPressed: run == null || !run.isRunning
                ? null
                : context.read<TagsCubit>().stopBatch,
          ),
        ),
      ),
    );
  }
}
