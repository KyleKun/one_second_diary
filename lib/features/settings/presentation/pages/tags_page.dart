import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/domain/tag_batch_event.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tags_help_sheet.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/tags_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/tags_state.dart';
import 'package:one_second_diary/features/settings/presentation/dialogs/tag_batch_dialog.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/edit_tag_sheet.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/surfaces/empty_state.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// Settings › Tags: every tag of every profile with its clip count, most
/// used first, each with a dot in its colour. A tap opens [EditTagSheet]
/// (rename, merge, colour, remove). While a rename or removal rewrites
/// the clips, [TagBatchDialog] shows its progress; the outcome is said
/// here once it closes. "?" in the app bar opens `TagsHelpSheet`.
class TagsPage extends StatelessWidget {
  const TagsPage({super.key});

  static const Key listKey = Key('tagsPage.list');

  static const Key emptyKey = Key('tagsPage.empty');

  /// "About tags", in the app bar.
  static const Key helpKey = Key('tagsPage.help');

  /// The row of one tag.
  static Key rowKey(String tag) =>
      ValueKey<String>('tagsPage.row.${TagName.fold(tag)}');

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: OsdAppBar(
        title: Strings.tags,
        trailing: OsdIconButton(
          key: helpKey,
          icon: OsdIcons.help,
          tooltip: Strings.tagsHelpTitle,
          onPressed: () => unawaited(TagsHelpSheet.show(context)),
        ),
      ),
      body: OsdSnackbarHost(
        child: _TagsFeedback(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: OsdSizes.contentMaxWidth,
              ),
              child: const _TagList(),
            ),
          ),
        ),
      ),
    );
  }
}

/// The list of tags, or the empty state once the library has been read.
class _TagList extends StatelessWidget {
  const _TagList();

  @override
  Widget build(BuildContext context) {
    final (List<TagCount> tags, bool loaded) = context.select(
      (TagsCubit cubit) => (cubit.state.tags, cubit.state.loaded),
    );
    // Repaints the dots when a colour changes.
    context.select((TagsCubit cubit) => cubit.state.colorsVersion);
    if (!loaded) return const SizedBox.shrink();
    if (tags.isEmpty) {
      return const Padding(
        key: TagsPage.emptyKey,
        padding: EdgeInsets.symmetric(horizontal: OsdSpace.textInset),
        child: _EmptyTags(),
      );
    }
    final TagColors tagColors = context.read<TagColors>();
    return ListView(
      key: TagsPage.listKey,
      padding: const EdgeInsets.fromLTRB(0, OsdSpace.s4, 0, OsdSpace.s24),
      children: <Widget>[
        OsdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < tags.length; i++) ...<Widget>[
                if (i > 0) const OsdDivider(),
                _TagRow(tag: tags[i], color: tagColors.colorOf(tags[i].name)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyTags extends StatelessWidget {
  const _EmptyTags();

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: OsdIcons.sell,
    title: Strings.tagsNoneYet,
    body: Strings.manageTagsDescription,
  );
}

/// One tag: a dot in its colour, its name and how many clips carry it.
class _TagRow extends StatelessWidget {
  const _TagRow({required this.tag, required this.color});

  final TagCount tag;
  final Color color;

  @override
  Widget build(BuildContext context) => OsdListRow(
    key: TagsPage.rowKey(tag.name),
    title: tag.name,
    value: Strings.tagVideoCount(
      tag.count,
      format: LocaleFormats.of(context).numbers,
    ),
    leading: _ColorDot(color: color),
    trailing: const OsdRowTrailing.chevron(),
    onTap: () => unawaited(
      EditTagSheet.show(context, cubit: context.read<TagsCubit>(), tag: tag),
    ),
  );
}

/// A 10 px disc in the tag's colour, where a row's icon sits.
class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  static const double _diameter = 10;

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: OsdSizes.iconDefault,
    child: Center(
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const SizedBox.square(dimension: _diameter),
      ),
    ),
  );
}

/// What the page shows around a batch: the progress dialog while it runs,
/// then its outcome ("3 videos updated"; "1 video couldn't be updated" as
/// an error; "Stopped" when the user stopped it), and "Couldn't save this
/// setting" when a colour could not be stored.
class _TagsFeedback extends StatelessWidget {
  const _TagsFeedback({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: <BlocListener<dynamic, dynamic>>[
      BlocListener<TagsCubit, TagsState>(
        listenWhen: (TagsState previous, TagsState current) =>
            !previous.isBatchRunning && current.isBatchRunning,
        listener: (BuildContext context, _) => unawaited(
          TagBatchDialog.show(context, cubit: context.read<TagsCubit>()),
        ),
      ),
      BlocListener<TagsCubit, TagsState>(
        listenWhen: (TagsState previous, TagsState current) =>
            previous.isBatchRunning &&
            !current.isBatchRunning &&
            current.batch?.finished != null,
        listener: (BuildContext context, TagsState state) =>
            _sayOutcome(context, state.batch!.finished!),
      ),
      BlocListener<TagsCubit, TagsState>(
        listenWhen: (TagsState previous, TagsState current) =>
            previous.colorSaveFailures < current.colorSaveFailures,
        listener: (BuildContext context, _) => OsdSnackbar.show(
          context,
          kind: OsdSnackKind.error,
          title: Strings.preferencesSaveFailed,
        ),
      ),
    ],
    child: child,
  );

  static void _sayOutcome(BuildContext context, TagBatchFinished outcome) {
    final String updated = Strings.tagBatchDone(
      outcome.updated,
      format: LocaleFormats.of(context).numbers,
    );
    if (outcome.stopped) {
      OsdSnackbar.show(
        context,
        kind: OsdSnackKind.info,
        title: Strings.tagBatchStopped,
        subtitle: updated,
      );
    } else if (outcome.failed > 0) {
      OsdSnackbar.show(
        context,
        kind: OsdSnackKind.error,
        title: Strings.tagBatchFailed(
          outcome.failed,
          format: LocaleFormats.of(context).numbers,
        ),
        subtitle: updated,
      );
    } else {
      OsdSnackbar.show(context, kind: OsdSnackKind.success, title: updated);
    }
  }
}
