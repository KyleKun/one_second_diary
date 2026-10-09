import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_event.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/movie_created_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_created_entrance.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_preview_card.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The movie is made: its preview, "Movie created!", where it was saved
/// (Android: DCIM/OneSecondDiary/Movies; iOS keeps movies in the app's own
/// folder and hides the line), Watch, Share and Done.
class MovieCreatedPage extends StatefulWidget {
  const MovieCreatedPage({super.key});

  static const Key titleKey = Key('movieCreatedPage.title');

  static const Key locationKey = Key('movieCreatedPage.location');

  static const Key skippedKey = Key('movieCreatedPage.skipped');
  static const Key leftOutPrivateKey = Key('movieCreatedPage.leftOutPrivate');

  static const Key watchKey = Key('movieCreatedPage.watch');

  static const Key shareKey = Key('movieCreatedPage.share');

  static const Key doneKey = Key('movieCreatedPage.done');

  static const double _maxWidth = 560;
  static const double _maxGroupWidth = 480;

  @override
  State<MovieCreatedPage> createState() => _MovieCreatedPageState();
}

class _MovieCreatedPageState extends State<MovieCreatedPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: MovieCreatedPart.total,
  );
  bool _entered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entered) return;
    _entered = true;
    if (OsdMotion.reduced(context)) {
      _entrance.value = 1;
    } else {
      unawaited(_entrance.forward());
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _watch(MovieEntry movie) =>
      unawaited(MoviePlayerArgs(file: movie.fileName).push<void>(context));

  /// Done and back: the flow ends where it started, and so does the job.
  void _done() {
    context.read<MovieJobBloc>().add(const MovieJobDismissed());
    // The flow is one page on the root navigator, right above the page it
    // was opened from (the tabs).
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    // The movie never changes while the page shows; only Share's spinner does,
    // which the footer follows on its own.
    final MovieCreatedState created = context.read<MovieCreatedCubit>().state;
    final MovieEntry? movie = created.movie;
    final OsdColors colors = context.colors;
    final double bottom = math.max(
      28,
      MediaQuery.viewPaddingOf(context).bottom + 8,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: MovieCreatedPage._maxWidth,
              ),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: MovieCreatedPage._maxGroupWidth,
                          ),
                          child: movie == null
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  spacing: 22,
                                  children: <Widget>[
                                    MovieCreatedEntrance(
                                      animation: _entrance,
                                      part: MovieCreatedPart.preview,
                                      child: MoviePreviewCard(
                                        file: movie.fileName,
                                        poster: created.poster,
                                        orientation: created.orientation,
                                        semanticsLabel: Strings.watchMovieNamed(
                                          name: MovieLabels.movieTitle(
                                            context,
                                            movie,
                                          ),
                                        ),
                                        onTap: () => _watch(movie),
                                      ),
                                    ),
                                    MovieCreatedEntrance(
                                      animation: _entrance,
                                      part: MovieCreatedPart.words,
                                      child: _Words(
                                        showsLocation: created.showsLocation,
                                        skippedClips: created.skippedClips,
                                        leftOutPrivateClips:
                                            created.leftOutPrivateClips,
                                      ),
                                    ),
                                    MovieCreatedEntrance(
                                      animation: _entrance,
                                      part: MovieCreatedPart.buttons,
                                      child: PrimaryButton(
                                        key: MovieCreatedPage.watchKey,
                                        label: Strings.movieWatch,
                                        icon: OsdIcons.playArrow,
                                        size: OsdButtonSize.large,
                                        onPressed: () => _watch(movie),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, bottom),
                    child: MovieCreatedEntrance(
                      animation: _entrance,
                      part: MovieCreatedPart.buttons,
                      child: _Footer(canShare: movie != null, onDone: _done),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Movie created!" over where it was saved and, when some clips could not
/// be read or turned out private, how many the movie was made without.
class _Words extends StatelessWidget {
  const _Words({
    required this.showsLocation,
    required this.skippedClips,
    required this.leftOutPrivateClips,
  });

  final bool showsLocation;
  final int skippedClips;
  final int leftOutPrivateClips;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    return Column(
      spacing: 8,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            Strings.movieCreatedTitle,
            key: MovieCreatedPage.titleKey,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            textScaler: OsdTextScale.scalerFor(
              context,
              OsdTextScaleRole.display,
            ),
            style: context.typography.title30Wrap.copyWith(color: colors.tx),
          ),
        ),
        if (showsLocation)
          Text(
            Strings.movieCreatedDesc,
            key: MovieCreatedPage.locationKey,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.typography.body14Loose.copyWith(color: colors.mu),
          ),
        if (skippedClips > 0)
          Text(
            Strings.movieSkippedClips(
              skippedClips,
              format: MovieLabels.numberFormat(context),
            ),
            key: MovieCreatedPage.skippedKey,
            textAlign: TextAlign.center,
            style: context.typography.body14Loose.copyWith(color: colors.mu),
          ),
        if (leftOutPrivateClips > 0)
          Text(
            Strings.moviePrivateClipsLeftOut(
              leftOutPrivateClips,
              format: MovieLabels.numberFormat(context),
            ),
            key: MovieCreatedPage.leftOutPrivateKey,
            textAlign: TextAlign.center,
            style: context.typography.body14Loose.copyWith(color: colors.mu),
          ),
      ],
    );
  }
}

/// Share (spinning while the sheet opens) and Done, side by side (the
/// order mirrors in RTL).
class _Footer extends StatelessWidget {
  const _Footer({required this.canShare, required this.onDone});

  final bool canShare;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final bool sharing = context.select<MovieCreatedCubit, bool>(
      (MovieCreatedCubit created) => created.state.sharing,
    );
    return Row(
      spacing: 10,
      children: <Widget>[
        if (canShare)
          Expanded(
            child: Builder(
              builder: (BuildContext button) => NeutralButton(
                key: MovieCreatedPage.shareKey,
                label: Strings.share,
                icon: OsdIcons.share,
                size: OsdButtonSize.medium,
                loading: sharing,
                onPressed: sharing ? null : () => _share(button),
              ),
            ),
          ),
        Expanded(
          child: NeutralButton(
            key: MovieCreatedPage.doneKey,
            label: Strings.done,
            size: OsdButtonSize.medium,
            onPressed: onDone,
          ),
        ),
      ],
    );
  }

  /// Shares the movie, the sheet anchored to [button] (iPad needs it).
  static void _share(BuildContext button) {
    final RenderObject? box = button.findRenderObject();
    final Rect? origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    unawaited(button.read<MovieCreatedCubit>().share(origin: origin));
  }
}
