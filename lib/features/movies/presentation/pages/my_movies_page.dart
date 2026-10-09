import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/my_movies_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/my_movies_state.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/my_movies_app_bar.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/my_movies_grid.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/my_movies_skeleton.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/rename_movie_dialog.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_loading_delay.dart';
import 'package:one_second_diary/shared/widgets/surfaces/empty_state.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// My movies and its selection mode: every movie of every profile, in `Movies/`
/// and its sub-folders, newest first.
class MyMoviesPage extends StatelessWidget {
  const MyMoviesPage({super.key});

  static const Key scrollKey = Key('myMoviesPage.scroll');

  static const Key renameKey = Key('myMoviesPage.rename');

  static const Key shareKey = Key('myMoviesPage.share');

  static const Key deleteKey = Key('myMoviesPage.delete');

  /// Music off/on, for the one selected movie with music.
  static const Key musicKey = Key('myMoviesPage.music');

  static const Key createMovieKey = Key('myMoviesPage.createMovie');

  static const Key retryKey = Key('myMoviesPage.retry');

  /// "Clear filter" in the "No movies match" state.
  static const Key clearFilterKey = Key('myMoviesPage.clearFilter');

  Future<void> _rename(BuildContext context) async {
    final MyMoviesCubit cubit = context.read<MyMoviesCubit>();
    final List<MovieEntry> selected = cubit.state.selectedMovies;
    if (selected.length != 1) return;
    await RenameMovieDialog.show(
      context,
      title: MovieLabels.baseTitle(context, selected.single),
      onSave: cubit.rename,
    );
  }

  Future<void> _delete(BuildContext context) async {
    final MyMoviesCubit cubit = context.read<MyMoviesCubit>();
    final List<MovieEntry> selected = cubit.state.selectedMovies;
    if (selected.isEmpty) return;
    final bool one = selected.length == 1;
    await OsdConfirmDialog.show(
      context,
      title: one
          ? Strings.deleteMovieTitle
          : Strings.deleteMoviesTitle(
              selected.length,
              format: MovieLabels.numberFormat(context),
            ),
      body: one
          ? Strings.deleteMovieBody(
              name: MovieLabels.movieTitleNow(context, selected.single),
            )
          : Strings.deleteMoviesBody,
      content: const _ClipsSafe(),
      badgeIcon: OsdIcons.delete,
      destructive: true,
      cancelLabel: CommonLabels.of(context).cancel,
      confirmLabel: CommonLabels.of(context).delete,
      onConfirm: cubit.deleteSelected,
    );
  }

  /// Shares the movies selected, the sheet anchored to [button].
  static void _share(BuildContext button) {
    final RenderObject? box = button.findRenderObject();
    final Rect? origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    unawaited(button.read<MyMoviesCubit>().shareSelected(origin: origin));
  }

  static void _say(BuildContext context, MyMoviesNotice notice) {
    final (OsdSnackKind kind, String title) = switch (notice) {
      MoviesDeletedNotice(:final int count) => (
        OsdSnackKind.delete,
        count == 1
            ? Strings.movieDeleted
            : Strings.moviesDeleted(
                count,
                format: MovieLabels.numberFormat(context),
              ),
      ),
      MovieDeleteFailedNotice() => (
        OsdSnackKind.error,
        Strings.movieDeleteFailed,
      ),
      MovieFileMissingNotice() => (OsdSnackKind.info, Strings.movieFileMissing),
      MovieMusicSwappedNotice(:final bool on) => (
        OsdSnackKind.info,
        on ? Strings.movieMusicOn : Strings.movieMusicOff,
      ),
      MovieMusicSwapFailedNotice() => (
        OsdSnackKind.error,
        Strings.movieMusicSwapError,
      ),
    };
    OsdSnackbar.show(context, kind: kind, title: title);
  }

  @override
  Widget build(BuildContext context) => _SelectionBack(
    child: Scaffold(
      backgroundColor: context.colors.bg,
      body: OsdSnackbarHost(
        child: BlocListener<MyMoviesCubit, MyMoviesState>(
          listenWhen: (MyMoviesState previous, MyMoviesState current) =>
              current.noticeId != previous.noticeId && current.notice != null,
          listener: (BuildContext context, MyMoviesState state) =>
              _say(context, state.notice!),
          child: Builder(
            builder: (BuildContext context) => Column(
              children: <Widget>[
                MyMoviesAppBar(
                  renameKey: renameKey,
                  shareKey: shareKey,
                  deleteKey: deleteKey,
                  musicKey: musicKey,
                  onRename: () => unawaited(_rename(context)),
                  onShare: _share,
                  onDelete: () => unawaited(_delete(context)),
                  onToggleMusic: () =>
                      unawaited(context.read<MyMoviesCubit>().toggleMusic()),
                ),
                const Expanded(child: _Body()),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Back leaves selection mode first.
class _SelectionBack extends StatelessWidget {
  const _SelectionBack({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool selecting = context.select<MyMoviesCubit, bool>(
      (MyMoviesCubit movies) => movies.state.selecting,
    );
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) context.read<MyMoviesCubit>().clearSelection();
      },
      child: child,
    );
  }
}

/// The list, the empty state, the filter that keeps nothing, the failure,
/// or the skeleton.
class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final (MyMoviesStatus status, bool empty, bool noMatches) = context
        .select<MyMoviesCubit, (MyMoviesStatus, bool, bool)>(
          (MyMoviesCubit movies) => (
            movies.state.status,
            movies.state.movies.isEmpty,
            movies.state.noMatches,
          ),
        );
    return AnimatedSwitcher(
      duration: OsdMotion.d(context, OsdMotion.fast),
      child: switch (status) {
        MyMoviesStatus.loading => OsdLoadingDelay(
          key: const ValueKey<MyMoviesStatus>(MyMoviesStatus.loading),
          loading: true,
          builder: (BuildContext context, bool show) =>
              show ? const MyMoviesSkeleton() : const SizedBox.expand(),
        ),
        MyMoviesStatus.failed => const _Failed(
          key: ValueKey<MyMoviesStatus>(MyMoviesStatus.failed),
        ),
        MyMoviesStatus.ready when empty => const _Empty(
          key: ValueKey<String>('empty'),
        ),
        MyMoviesStatus.ready when noMatches => const _NoMatches(
          key: ValueKey<String>('noMatches'),
        ),
        MyMoviesStatus.ready => const _Movies(
          key: ValueKey<MyMoviesStatus>(MyMoviesStatus.ready),
        ),
      },
    );
  }
}

/// The grid.
class _Movies extends StatelessWidget {
  const _Movies({super.key});

  @override
  Widget build(BuildContext context) => CustomScrollView(
    key: MyMoviesPage.scrollKey,
    slivers: <Widget>[
      SliverPadding(
        padding: EdgeInsetsDirectional.fromSTEB(
          OsdSpace.pageGutter,
          OsdSpace.s8,
          OsdSpace.pageGutter,
          OsdSpace.s24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        sliver: const MyMoviesGrid(),
      ),
    ],
  );
}

/// No movies yet: Create movie opens the flow in My movies' place.
class _Empty extends StatelessWidget {
  const _Empty({super.key});

  @override
  Widget build(BuildContext context) => _Centered(
    child: EmptyState(
      icon: OsdIcons.videoLibrary,
      title: Strings.noMoviesFound,
      body: Strings.myMoviesEmptyBody,
      action: PrimaryButton(
        key: MyMoviesPage.createMovieKey,
        label: Strings.createMovie,
        icon: OsdIcons.movie,
        onPressed: () => unawaited(
          const CreateMovieArgs(replacing: true).pushReplacement<void>(context),
        ),
      ),
    ),
  );
}

/// The profile filter keeps no movie (the last one it kept was deleted):
/// Clear filter shows every movie again.
class _NoMatches extends StatelessWidget {
  const _NoMatches({super.key});

  @override
  Widget build(BuildContext context) => _Centered(
    child: EmptyState(
      icon: OsdIcons.filterList,
      title: Strings.movieFilterNoMatches,
      action: NeutralButton(
        key: MyMoviesPage.clearFilterKey,
        label: Strings.diaryFilterClear,
        hug: true,
        onPressed: context.read<MyMoviesCubit>().clearProfileFilter,
      ),
    ),
  );
}

/// `Movies/` could not be read (storage access lost): why, and Try again.
class _Failed extends StatelessWidget {
  const _Failed({super.key});

  @override
  Widget build(BuildContext context) => _Centered(
    child: EmptyState(
      icon: OsdIcons.error,
      title: Strings.myMoviesLoadFailed,
      body: Strings.myMoviesLoadFailedHint,
      action: NeutralButton(
        key: MyMoviesPage.retryKey,
        label: Strings.commonTryAgain,
        hug: true,
        onPressed: () => unawaited(context.read<MyMoviesCubit>().load()),
      ),
    ),
  );
}

/// [child] centred in the page, scrolling when large text makes it taller.
class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) =>
        SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: math.max(
              OsdSpace.s24,
              MediaQuery.viewPaddingOf(context).bottom,
            ),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        ),
  );
}

/// "Your daily clips are not affected." under the delete question.
class _ClipsSafe extends StatelessWidget {
  const _ClipsSafe();

  @override
  Widget build(BuildContext context) => Text(
    Strings.deleteMovieClipsSafe,
    textAlign: TextAlign.center,
    style: context.typography.body14.copyWith(color: context.colors.mu),
  );
}
