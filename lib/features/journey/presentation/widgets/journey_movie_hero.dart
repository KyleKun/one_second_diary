import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/journey_cubit.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/journey_state.dart';
import 'package:one_second_diary/features/journey/presentation/journey_formats.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_movie_job_card.dart';
import 'package:one_second_diary/features/movies/data/movie_posters.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/domain/movie_rules.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_poster_view.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_skeleton_block.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/theme/light_hairline.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The Journey's movie card: "Create a movie" over the clips available, a
/// full-width Start, then My movies (the newest posters fanned, the count,
/// a chevron) attached below.
///
/// With fewer clips than a movie needs, Start is off and "You need at least
/// 2 clips to make a movie." sits above it; while the diary is still being
/// read it stays on. While a movie is being made (or failed where the
/// making-movie page has not shown it) [JourneyMovieJobCard] takes the
/// body's place, one movie at a time; the two crossfade while the height
/// eases.
class JourneyMovieHero extends StatelessWidget {
  const JourneyMovieHero({
    super.key,
    required this.onCreateMovie,
    required this.onMyMovies,
    required this.onMovieJob,
  });

  /// The Start button.
  static const Key createMovieKey = Key('journeyMovieHero.createMovie');

  /// The "not enough clips" caption.
  static const Key needClipsKey = Key('journeyMovieHero.needClips');

  /// The My movies row.
  static const Key myMoviesKey = Key('journeyMovieHero.myMovies');

  /// The movie count under "My movies" ("4 movies", "No movies yet").
  static const Key movieCountKey = Key('journeyMovieHero.movieCount');

  final VoidCallback onCreateMovie;
  final VoidCallback onMyMovies;

  /// Opens the making-movie page on the movie being made.
  final VoidCallback onMovieJob;

  @override
  Widget build(BuildContext context) {
    final bool making = context.select<MovieJobBloc, bool>(
      (MovieJobBloc job) => JourneyMovieJobCard.offers(job.state),
    );
    final BorderRadius radius = BorderRadius.circular(OsdRadius.r24);
    return LightHairline(
      radius: radius,
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: context.colors.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: AnimatedSize(
                  duration: OsdMotion.d(context, OsdMotion.standard),
                  curve: OsdMotion.curve(context, OsdMotion.standardCurve),
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: OsdMotion.d(context, OsdMotion.fast),
                    switchInCurve: OsdMotion.fastCurve,
                    switchOutCurve: OsdMotion.fastCurve,
                    layoutBuilder: (Widget? current, List<Widget> previous) =>
                        Stack(
                          alignment: Alignment.topCenter,
                          children: <Widget>[...previous, ?current],
                        ),
                    child: making
                        ? JourneyMovieJobCard(
                            key: const ValueKey<bool>(true),
                            onTap: onMovieJob,
                          )
                        : _CreateMovie(
                            key: const ValueKey<bool>(false),
                            onCreateMovie: onCreateMovie,
                          ),
                  ),
                ),
              ),
              const OsdDivider.full(),
              _MyMoviesRow(onTap: onMyMovies),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the body shows of the Journey state.
typedef _Clips = ({JourneyStatus status, int clipCount});

/// "Create a movie", the clips available and Start, off with the reason
/// above it while the diary has too few clips.
class _CreateMovie extends StatelessWidget {
  const _CreateMovie({super.key, required this.onCreateMovie});

  final VoidCallback onCreateMovie;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final _Clips clips = context.select<JourneyCubit, _Clips>(
      (JourneyCubit cubit) =>
          (status: cubit.state.status, clipCount: cubit.state.clipCount),
    );
    final bool ready = clips.status == JourneyStatus.ready;
    final bool canCreate = !ready || clips.clipCount >= MovieRules.minClips;
    final TextStyle caption = typography.caption13.copyWith(color: colors.mu);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          Strings.journeyCreateMovie,
          style: typography.displayValue.copyWith(color: colors.tx),
        ),
        const SizedBox(height: 4),
        switch (clips.status) {
          JourneyStatus.loading => const Align(
            alignment: AlignmentDirectional.centerStart,
            child: OsdSkeletonBlock.text(width: 120),
          ),
          JourneyStatus.failed => Text('—', style: caption),
          JourneyStatus.ready => Text(
            Strings.journeyClipsAvailable(
              clips: Strings.clipCount(
                clips.clipCount,
                format: JourneyFormats.numberFormat(context),
              ),
            ),
            style: caption,
          ),
        },
        SizedBox(height: canCreate ? 28 : 16),
        if (!canCreate)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              Strings.movieInsufficientVideos,
              key: JourneyMovieHero.needClipsKey,
              textAlign: TextAlign.center,
              style: caption,
            ),
          ),
        PrimaryButton(
          key: JourneyMovieHero.createMovieKey,
          label: Strings.journeyStart,
          size: OsdButtonSize.hero,
          onPressed: canCreate ? onCreateMovie : null,
        ),
      ],
    );
  }
}

/// My movies under the hero: the newest posters fanned (an outlined empty
/// frame without any), the count, a chevron.
class _MyMoviesRow extends StatelessWidget {
  const _MyMoviesRow({required this.onTap});

  final VoidCallback onTap;

  static const double _thumbWidth = 34;
  static const double _thumbHeight = 44;
  static const double _overlap = 14;
  static const int _shown = 3;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final List<MovieEntry>? movies = context
        .select<JourneyCubit, List<MovieEntry>?>(
          (JourneyCubit cubit) => cubit.state.movies,
        );
    final List<MovieEntry> newest = movies?.take(_shown).toList() ?? const [];
    final int frames = newest.isEmpty ? 1 : newest.length;
    final String? count = movies == null
        ? null
        : movies.isEmpty
        ? Strings.noMoviesFound
        : Strings.journeyMovieCount(
            movies.length,
            format: JourneyFormats.numberFormat(context),
          );
    final BorderRadius radius = BorderRadius.circular(OsdRadius.r8);
    return OsdPressable(
      key: JourneyMovieHero.myMoviesKey,
      onTap: onTap,
      pressScale: null,
      semanticsLabel: count == null
          ? Strings.myMovies
          : '${Strings.myMovies}, $count',
      excludeChildSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 16, 14),
        child: Row(
          spacing: 12,
          children: <Widget>[
            SizedBox(
              width: _thumbWidth + (frames - 1) * (_thumbWidth - _overlap),
              height: _thumbHeight,
              child: Stack(
                children: <Widget>[
                  for (int i = frames - 1; i >= 0; i--)
                    PositionedDirectional(
                      start: i * (_thumbWidth - _overlap),
                      child: Container(
                        width: _thumbWidth,
                        height: _thumbHeight,
                        decoration: BoxDecoration(
                          color: i < newest.length ? null : colors.c2,
                          borderRadius: radius,
                          border: Border.all(
                            color: i < newest.length ? colors.card : colors.ln,
                            width: 2,
                          ),
                        ),
                        child: i < newest.length
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  OsdRadius.r8 - 2,
                                ),
                                child: MoviePosterView(
                                  posters: context.read<MoviePosters>(),
                                  file: newest[i].fileName,
                                  orientation: newest[i].orientation,
                                ),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    Strings.myMovies,
                    style: typography.rowTitleStrong.copyWith(color: colors.tx),
                  ),
                  if (count == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 3),
                      child: OsdSkeletonBlock.text(width: 60),
                    )
                  else
                    Text(
                      count,
                      key: JourneyMovieHero.movieCountKey,
                      style: typography.caption13.copyWith(color: colors.mu),
                    ),
                ],
              ),
            ),
            OsdIcon(OsdIcons.chevronRight, size: 22, color: colors.mu),
          ],
        ),
      ),
    );
  }
}
