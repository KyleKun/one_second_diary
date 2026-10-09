import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tag_filter_sheet.dart';
import 'package:one_second_diary/features/movies/domain/clip_months.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_state.dart';
import 'package:one_second_diary/features/movies/presentation/flow_profile.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/pick_clips_bar.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/pick_clips_grid.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_loading_delay.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_spinner.dart';
import 'package:one_second_diary/shared/widgets/surfaces/empty_state.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// Pick videos myself: the flow profile's clips by month, the newest first,
/// picked one by one or all at once (the app bar); the count and Continue
/// below.
class PickClipsPage extends StatelessWidget {
  const PickClipsPage({super.key});

  /// The app bar's "Select all" / "Deselect all".
  static const Key selectAllKey = Key('pickClipsPage.selectAll');

  /// The app bar's tag filter.
  static const Key filterKey = Key('pickClipsPage.filter');

  /// The dot on the filter while one is on.
  static const Key filterDotKey = Key('pickClipsPage.filterDot');

  @override
  Widget build(BuildContext context) {
    // The grid shows the clips through the tag filter; its identity holds
    // across picks, so a pick never rebuilds the page.
    final ({CreateMovieStatus status, ClipIndex? index}) flow = context
        .select<
          CreateMovieCubit,
          ({CreateMovieStatus status, ClipIndex? index})
        >(
          (CreateMovieCubit flow) =>
              (status: flow.state.status, index: flow.state.pickIndex),
        );
    final Profile? profile = FlowProfile.watch(context);
    final bool severalProfiles = context.select<ProfilesCubit, bool>(
      (ProfilesCubit profiles) => profiles.state.profiles.length > 1,
    );
    final ClipIndex? index = flow.index;
    final List<ClipMonth> months = index == null
        ? const <ClipMonth>[]
        : ClipMonths.of(index);
    final bool loading = flow.status == CreateMovieStatus.loading;
    final bool hasTags = context.select<CreateMovieCubit, bool>(
      (CreateMovieCubit flow) => flow.state.index?.hasTags ?? false,
    );
    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: OsdAppBar(
        title: Strings.selectVideos,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (hasTags) const _FilterButton(),
            if (months.isNotEmpty) const _SelectAllLink(),
          ],
        ),
      ),
      body: switch (months) {
        _ when loading => OsdLoadingDelay(
          loading: true,
          builder: (BuildContext context, bool show) =>
              Center(child: show ? const OsdSpinner() : null),
        ),
        _ when flow.status == CreateMovieStatus.failed => Center(
          child: EmptyState(
            icon: OsdIcons.error,
            title: Strings.storageUnavailableTitle,
            body: Strings.diaryUnreadableHint,
            action: NeutralButton(
              label: Strings.commonTryAgain,
              hug: true,
              onPressed: () =>
                  unawaited(context.read<CreateMovieCubit>().readAgain()),
            ),
          ),
        ),
        <ClipMonth>[] => Center(
          child: EmptyState(
            icon: OsdIcons.videocamOff,
            title: Strings.pickVideosEmptyTitle,
            body: Strings.pickVideosEmptyBody,
          ),
        ),
        _ => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: PickClipsGrid(
                months: months,
                orientation: profile?.orientation ?? VideoOrientation.landscape,
                profileName: severalProfiles ? profile?.displayName : null,
              ),
            ),
            const PickClipsBar(),
          ],
        ),
      },
    );
  }
}

/// The tag filter in the app bar: opens "Only videos tagged…" over the
/// profile's tags; a dot marks a filter in force.
class _FilterButton extends StatelessWidget {
  const _FilterButton();

  @override
  Widget build(BuildContext context) {
    final bool active = context.select<CreateMovieCubit, bool>(
      (CreateMovieCubit flow) => flow.state.tags.isNotEmpty,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        OsdIconButton(
          key: PickClipsPage.filterKey,
          icon: OsdIcons.filterList,
          tooltip: Strings.movieOnlyTagged,
          color: active ? context.colors.co : null,
          onPressed: () => unawaited(_pick(context)),
        ),
        if (active)
          PositionedDirectional(
            top: 8,
            end: 8,
            child: IgnorePointer(
              child: Container(
                key: PickClipsPage.filterDotKey,
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.colors.co,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final CreateMovieCubit flow = context.read<CreateMovieCubit>();
    final Set<String>? picked = await TagFilterSheet.show(
      context,
      title: Strings.movieOnlyTagged,
      tags: flow.state.index?.tagCounts ?? const <TagCount>[],
      initial: flow.state.tags.anyOf,
      searchHint: Strings.diarySearchHint,
    );
    if (picked != null) flow.setOnlyTags(picked);
  }
}

/// "Select all" in the app bar, "Deselect all" once every clip is picked.
class _SelectAllLink extends StatelessWidget {
  const _SelectAllLink();

  @override
  Widget build(BuildContext context) {
    final bool allPicked = context.select<CreateMovieCubit, bool>(
      (CreateMovieCubit flow) => flow.state.allPicked,
    );
    return OsdTextButton(
      key: PickClipsPage.selectAllKey,
      label: allPicked
          ? Strings.deselectAll
          : CommonLabels.of(context).selectAll,
      hug: true,
      onPressed: () => context.read<CreateMovieCubit>().toggleAll(),
    );
  }
}
