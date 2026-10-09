import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/router/tab_reselect_listener.dart';
import 'package:one_second_diary/features/diary/presentation/diary_opener.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/journey_cubit.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/journey_state.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_entrance.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_movie_hero.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_profile_chip.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_stats_bento.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_state.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_display_title.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_callout.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The Journey tab: "Journey" with the profile chip, the movie card
/// (Create a movie with Start, My movies), then "Stats" over the grouped
/// stat tiles (the whole page scrolls; at most [_maxWidth] wide on a
/// tablet).
///
/// The page lives as long as the tab, so its entrance and its count-up run
/// once per session: the card and the groups rise in when the tab first
/// shows, and the numbers count from 0 the first time the stats are there
/// (at once when the diary was already read). Under reduced motion
/// everything is final. Hidden, the tab's animations pause (`TickerMode`).
///
/// Tiles lead on: "Days recorded" and "This month" to the Diary's calendar
/// of this month (through the app's `DiaryOpener`), Footage to Create movie
/// with "All time" picked, Places to the Places page, My movies to the
/// list. While a movie is being made away from the making-movie page, its
/// card takes Start's place and leads back to it.
class JourneyPage extends StatefulWidget {
  const JourneyPage({super.key});

  static const double _maxWidth = 560;

  @override
  State<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends State<JourneyPage>
    with TickerProviderStateMixin {
  late final AnimationController _countUp = AnimationController(
    vsync: this,
    duration: OsdMotion.countUp + OsdMotion.countUpStagger * 5,
  );
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: JourneyEntrance.duration,
  );
  final ScrollController _scroll = ScrollController();
  bool _started = false;
  bool _counted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (OsdMotion.reduced(context)) {
      _entrance.value = 1;
    } else {
      unawaited(_entrance.forward());
    }
    if (context.read<JourneyCubit>().state.status == JourneyStatus.ready) {
      _startCountUp();
    }
  }

  @override
  void dispose() {
    _countUp.dispose();
    _entrance.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// "Days recorded" and "This month": the Diary tab on this month's
  /// calendar, whatever month and view it was left on.
  void _openThisMonth() {
    context.read<DiaryOpener>().showThisMonthsCalendar();
    AppRoute.diary.go(context);
  }

  /// The first time the stats are there, the numbers count up; never again
  /// this session.
  void _startCountUp() {
    if (_counted) return;
    _counted = true;
    if (OsdMotion.reduced(context)) {
      _countUp.value = 1;
    } else {
      unawaited(_countUp.forward());
    }
  }

  Future<void> _openMyMovies() async {
    await AppRoute.myMovies.push<void>(context);
    if (mounted) await context.read<JourneyCubit>().refreshMovies();
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: <BlocListener<Object?, Object?>>[
      BlocListener<JourneyCubit, JourneyState>(
        listenWhen: (JourneyState previous, JourneyState current) =>
            current.status == JourneyStatus.ready,
        listener: (BuildContext context, JourneyState state) => _startCountUp(),
      ),
      // A movie made from anywhere (here, the Diary) is one more movie.
      BlocListener<MovieJobBloc, MovieJobState>(
        listenWhen: (MovieJobState previous, MovieJobState current) =>
            current.status == MovieJobStatus.done &&
            previous.status != MovieJobStatus.done,
        listener: (BuildContext context, MovieJobState state) =>
            unawaited(context.read<JourneyCubit>().refreshMovies()),
      ),
    ],
    child: ColoredBox(
      color: context.colors.bg,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: JourneyPage._maxWidth),
            child: TabReselectListener(
              tab: AppRoute.journey,
              scrollController: _scroll,
              child: CustomScrollView(
                controller: _scroll,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: OsdDisplayTitle(title: Strings.journey),
                        ),
                        const Padding(
                          padding: EdgeInsetsDirectional.only(end: 16),
                          child: JourneyProfileChip(),
                        ),
                      ],
                    ),
                  ),
                  const SliverToBoxAdapter(child: _Unreadable()),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      32 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 22,
                        children: <Widget>[
                          JourneyEntrance(
                            animation: _entrance,
                            index: 0,
                            child: JourneyMovieHero(
                              onCreateMovie: () => unawaited(
                                const CreateMovieArgs().push<void>(context),
                              ),
                              onMyMovies: _openMyMovies,
                              onMovieJob: () => unawaited(
                                AppRoute.makingMovie.push<void>(context),
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 12,
                            children: <Widget>[
                              JourneyEntrance(
                                animation: _entrance,
                                index: 1,
                                child: _SectionTitle(Strings.journeyStats),
                              ),
                              RepaintBoundary(
                                child: JourneyStatsBento(
                                  countUp: _countUp,
                                  entrance: _entrance,
                                  onDaysTap: _openThisMonth,
                                  onFootageTap: () => unawaited(
                                    const CreateMovieArgs(
                                      preset: MoviePreset.allTime,
                                    ).push<void>(context),
                                  ),
                                  onPlacesTap: () => unawaited(
                                    AppRoute.placesMap.push<void>(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// "Stats", a heading over the groups.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 4),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: context.typography.displayValue.copyWith(
          color: context.colors.tx,
        ),
      ),
    ),
  );
}

/// Above the movie card when the diary could not be read (the tiles show
/// "—"): why, and Try again.
class _Unreadable extends StatelessWidget {
  const _Unreadable();

  @override
  Widget build(BuildContext context) {
    final bool failed = context.select<JourneyCubit, bool>(
      (JourneyCubit cubit) => cubit.state.status == JourneyStatus.failed,
    );
    if (!failed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 10),
      child: OsdCallout.banner(
        icon: OsdIcons.error,
        title: Strings.storageUnavailableTitle,
        text: Strings.diaryUnreadableHint,
        actionLabel: Strings.commonTryAgain,
        onAction: () => unawaited(context.read<JourneyCubit>().readAgain()),
      ),
    );
  }
}
