import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/my_movies_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/features/movies/presentation/sheets/movies_profile_filter_sheet.dart';
import 'package:one_second_diary/features/movies/presentation/sheets/my_movies_help_sheet.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/shared/widgets/chrome/selection_app_bar.dart';
import 'package:one_second_diary/shared/widgets/controls/tag_chip.dart';
import 'package:one_second_diary/shared/widgets/controls/view_toggle.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// My movies' bar: "My movies" with back, the profile filter button (a dot on
/// it while a filter is on; only once the movies come from more than one
/// profile), the view toggle (grid or large) and the help button, crossfading
/// into the selection bar while movies are selected: close, "{n} selected",
/// Rename (off unless exactly one is selected), Share and Delete, and Music
/// off/on for a movie with music.
class MyMoviesAppBar extends StatelessWidget {
  const MyMoviesAppBar({
    super.key,
    required this.onRename,
    required this.onShare,
    required this.onDelete,
    required this.onToggleMusic,
    required this.renameKey,
    required this.shareKey,
    required this.deleteKey,
    required this.musicKey,
  });

  final VoidCallback onRename;

  /// Turns the one selected movie's music off or on; the button is there only
  /// when that movie has music.
  final VoidCallback onToggleMusic;

  /// Shares, the sheet anchored to the button ([BuildContext] of the
  /// button).
  final ValueChanged<BuildContext> onShare;
  final VoidCallback onDelete;

  final Key renameKey;
  final Key shareKey;
  final Key deleteKey;
  final Key musicKey;

  static const Key helpKey = Key('myMoviesAppBar.help');

  /// The filter button.
  static const Key filterKey = Key('myMoviesAppBar.filter');

  /// The dot on the filter button while a filter is on.
  static const Key filterDotKey = Key('myMoviesAppBar.filterDot');

  /// "Clear filter" under the bar.
  static const Key clearKey = Key('myMoviesAppBar.clear');

  /// "N movies" under the bar.
  static const Key matchesKey = Key('myMoviesAppBar.matches');

  /// The chip of [profile] in the summary (null: "Movies without a
  /// profile").
  static Key profileChipKey(ProfileKey? profile) =>
      ValueKey<String?>('myMoviesAppBar.profileChip.${profile?.value}');

  static const double _dotSize = 7;

  /// Opens the filter sheet on the filter; My movies follows every change,
  /// and the result when the sheet closes with Done.
  static Future<void> openFilter(BuildContext context) async {
    final MyMoviesCubit cubit = context.read<MyMoviesCubit>();
    final Set<ProfileKey?>? chosen = await MoviesProfileFilterSheet.show(
      context,
      choices: cubit.state.profileCounts,
      initial: cubit.state.profileFilter,
      onChanged: cubit.setProfileFilter,
    );
    if (chosen != null && !cubit.isClosed) cubit.setProfileFilter(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final (int count, bool sharing, bool filtered) = context
        .select<MyMoviesCubit, (int, bool, bool)>(
          (MyMoviesCubit movies) => (
            movies.state.selected.length,
            movies.state.sharing,
            movies.state.isFiltered,
          ),
        );
    // Whether the one movie selected has music, and whether it plays;
    // null without such a movie.
    final (bool? musicOn, bool swapping) = context
        .select<MyMoviesCubit, (bool?, bool)>(
          (MyMoviesCubit movies) =>
              (movies.state.musicMovie?.musicOn, movies.state.swappingMusic),
        );
    final OsdColors colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: OsdSizes.appBarHeight + MediaQuery.paddingOf(context).top,
          child: AnimatedSwitcher(
            duration: OsdMotion.d(context, OsdMotion.standard),
            switchInCurve: OsdMotion.curve(context, OsdMotion.fastCurve),
            switchOutCurve: OsdMotion.curve(context, OsdMotion.fastCurve),
            child: count == 0
                ? OsdAppBar(
                    key: const ValueKey<bool>(false),
                    title: Strings.myMovies,
                    trailing: const _FilterViewAndHelp(),
                  )
                : SelectionAppBar(
                    key: const ValueKey<bool>(true),
                    title: Strings.selectedCount(
                      count,
                      format: MovieLabels.numberFormat(context),
                    ),
                    closeTooltip: Strings.selectionClose,
                    onClose: () =>
                        context.read<MyMoviesCubit>().clearSelection(),
                    actions: <Widget>[
                      OsdIconButton(
                        key: renameKey,
                        icon: OsdIcons.driveFileRenameOutline,
                        tooltip: Strings.commonRename,
                        fadeWhenDisabled: true,
                        onPressed: count == 1 ? onRename : null,
                      ),
                      if (musicOn != null)
                        OsdIconButton(
                          key: musicKey,
                          icon: musicOn
                              ? OsdIcons.volumeOff
                              : OsdIcons.volumeUp,
                          tooltip: musicOn
                              ? Strings.movieMusicTurnOff
                              : Strings.movieMusicTurnOn,
                          fadeWhenDisabled: true,
                          onPressed: swapping ? null : onToggleMusic,
                        ),
                      Builder(
                        builder: (BuildContext button) => OsdIconButton(
                          key: shareKey,
                          icon: OsdIcons.share,
                          tooltip: Strings.share,
                          fadeWhenDisabled: true,
                          onPressed: sharing ? null : () => onShare(button),
                        ),
                      ),
                      OsdIconButton(
                        key: deleteKey,
                        icon: OsdIcons.delete,
                        tooltip: CommonLabels.of(context).delete,
                        color: colors.red,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
          ),
        ),
        AnimatedSize(
          duration: OsdMotion.d(context, OsdMotion.standard),
          curve: OsdMotion.curve(context, OsdMotion.standardCurve),
          alignment: AlignmentDirectional.topStart,
          child: filtered ? const _FilterSummary() : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// The bar's end: the filter button (only while there is something to filter:
/// movies of more than one profile), the grid ↔ large toggle (as the Diary's
/// calendar ↔ Memories one), then "About movies".
class _FilterViewAndHelp extends StatelessWidget {
  const _FilterViewAndHelp();

  @override
  Widget build(BuildContext context) {
    final (bool large, bool canFilter, bool filtered) = context
        .select<MyMoviesCubit, (bool, bool, bool)>(
          (MyMoviesCubit movies) => (
            movies.state.largeView,
            movies.state.profileCounts.length > 1,
            movies.state.isFiltered,
          ),
        );
    final OsdColors colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (canFilter)
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              OsdIconButton(
                key: MyMoviesAppBar.filterKey,
                icon: OsdIcons.filterList,
                tooltip: Strings.movieFilterByProfile,
                color: filtered ? colors.co : null,
                onPressed: () => unawaited(MyMoviesAppBar.openFilter(context)),
              ),
              if (filtered)
                PositionedDirectional(
                  top: 9,
                  end: 9,
                  child: IgnorePointer(
                    child: SizedBox.square(
                      key: MyMoviesAppBar.filterDotKey,
                      dimension: MyMoviesAppBar._dotSize,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.co,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ViewToggle(
          options: <ViewToggleOption>[
            ViewToggleOption(
              icon: OsdIcons.calendarViewMonth,
              tooltip: Strings.myMoviesViewGrid,
            ),
            ViewToggleOption(
              icon: OsdIcons.viewAgenda,
              tooltip: Strings.myMoviesViewLarge,
            ),
          ],
          index: large ? 1 : 0,
          onChanged: (int index) => unawaited(
            context.read<MyMoviesCubit>().showLargeView(large: index == 1),
          ),
        ),
        OsdIconButton(
          key: MyMoviesAppBar.helpKey,
          icon: OsdIcons.help,
          tooltip: Strings.myMoviesHelpTitle,
          onPressed: () => unawaited(MyMoviesHelpSheet.show(context)),
        ),
      ],
    );
  }
}

/// What the filter keeps, under the bar: the profiles chosen as chips,
/// "N movies" and Clear.
class _FilterSummary extends StatelessWidget {
  const _FilterSummary();

  @override
  Widget build(BuildContext context) {
    final (Set<ProfileKey?> filter, int matches) = context
        .select<MyMoviesCubit, (Set<ProfileKey?>, int)>(
          (MyMoviesCubit movies) =>
              (movies.state.profileFilter, movies.state.visibleMovies.length),
        );
    final MyMoviesCubit cubit = context.read<MyMoviesCubit>();
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        OsdSpace.pageGutter,
        OsdSpace.s4,
        OsdSpace.pageGutter,
        OsdSpace.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: OsdSpace.s6,
        children: <Widget>[
          Wrap(
            spacing: OsdSpace.s6,
            runSpacing: OsdSpace.s6,
            children: <Widget>[
              for (final ProfileKey? profile in filter)
                TagChip(
                  key: MyMoviesAppBar.profileChipKey(profile),
                  label: MoviesProfileFilterSheet.nameOf(context, profile),
                  color: profile == null ? colors.mu : colors.co,
                  compact: true,
                  onRemove: () => cubit.setProfileFilter(
                    <ProfileKey?>{...filter}..remove(profile),
                  ),
                ),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  Strings.movieFilterMatches(
                    matches,
                    format: MovieLabels.numberFormat(context),
                  ),
                  key: MyMoviesAppBar.matchesKey,
                  style: typography.caption13.copyWith(color: colors.sub),
                ),
              ),
              OsdTextButton(
                key: MyMoviesAppBar.clearKey,
                label: Strings.diaryFilterClear,
                tone: OsdTextButtonTone.secondary,
                hug: true,
                onPressed: cubit.clearProfileFilter,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
