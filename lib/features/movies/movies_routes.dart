import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/platform/screen_orientation_gateway.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/landscape_while_open.dart';
import 'package:one_second_diary/core/router/osd_pages.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/router/route_guards.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/movies/data/movie_posters.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/movie_created_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/movie_player_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/my_movies_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/pages/confirm_movie_page.dart';
import 'package:one_second_diary/features/movies/presentation/pages/create_movie_page.dart';
import 'package:one_second_diary/features/movies/presentation/pages/making_movie_page.dart';
import 'package:one_second_diary/features/movies/presentation/pages/movie_created_page.dart';
import 'package:one_second_diary/features/movies/presentation/pages/movie_player_page.dart';
import 'package:one_second_diary/features/movies/presentation/pages/my_movies_page.dart';
import 'package:one_second_diary/features/movies/presentation/pages/pick_clips_page.dart';
import 'package:one_second_diary/features/settings/presentation/report_error/report_error_cubit.dart';
import 'package:one_second_diary/theme/osd_forced_dark.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The movie routes, on the root navigator.
List<RouteBase> moviesRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoute.myMovies.path,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        OsdPages.material(
          state,
          RepositoryProvider<MoviePosters>.value(
            value: sl<MoviePosters>(),
            child: BlocProvider<MyMoviesCubit>(
              create: (_) => sl<MyMoviesCubit>(),
              child: const MyMoviesPage(
                key: ValueKey<AppRoute>(AppRoute.myMovies),
              ),
            ),
          ),
        ),
    routes: <RouteBase>[
      // The player, always dark: the movie flies in from its tile or the
      // created page's preview, and plays through its own player pool, with
      // sound.
      GoRoute(
        path: AppRoute.moviePlayer.pathBelow(AppRoute.myMovies),
        redirect: (BuildContext context, GoRouterState state) =>
            (movieFileOf(state) ?? '').isEmpty ? AppRoute.myMovies.path : null,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            OsdPages.mediaFlight(
              state,
              OsdForcedDark(
                child: LandscapeWhileOpen(
                  orientation: sl<ScreenOrientationGateway>(),
                  child: RepositoryProvider<PlayerPool>(
                    create: (_) => sl<PlayerPool>(param1: false),
                    dispose: (PlayerPool pool) => unawaited(pool.dispose()),
                    child: RepositoryProvider<MoviePosters>.value(
                      value: sl<MoviePosters>(),
                      child: BlocProvider<MoviePlayerCubit>(
                        create: (_) =>
                            sl<MoviePlayerCubit>(param1: movieFileOf(state)),
                        child: const MoviePlayerPage(
                          key: ValueKey<AppRoute>(AppRoute.moviePlayer),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              duration: OsdMotion.emphasized,
            ),
      ),
    ],
  ),
  ShellRoute(
    pageBuilder: (BuildContext context, GoRouterState state, Widget child) =>
        OsdPages.flow(
          state,
          BlocProvider<CreateMovieCubit>(
            // Made in the flow's first build, the one with the arguments the
            // flow opened with: a later push inside the flow builds this again
            // without them (`extra` is the top route's).
            lazy: false,
            create: (_) => sl<CreateMovieCubit>(
              param1:
                  maybeArgsOf<CreateMovieArgs>(state) ??
                  const CreateMovieArgs(),
            ),
            child: child,
          ),
          // From My movies' empty state the flow takes its place (the
          // fade-through); the route keeps it through those later builds.
          replacing: maybeArgsOf<CreateMovieArgs>(state)?.replacing ?? false,
        ),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.createMovie.path,
        redirect: allowArgs<CreateMovieArgs>(orElse: AppRoute.journey),
        pageBuilder: (BuildContext context, GoRouterState state) =>
            OsdPages.material(
              state,
              const CreateMoviePage(
                key: ValueKey<AppRoute>(AppRoute.createMovie),
              ),
            ),
        routes: <RouteBase>[
          GoRoute(
            path: AppRoute.pickClips.pathBelow(AppRoute.createMovie),
            pageBuilder: (BuildContext context, GoRouterState state) =>
                OsdPages.material(
                  state,
                  const PickClipsPage(
                    key: ValueKey<AppRoute>(AppRoute.pickClips),
                  ),
                ),
          ),
          GoRoute(
            path: AppRoute.confirmMovie.pathBelow(AppRoute.createMovie),
            pageBuilder: (BuildContext context, GoRouterState state) =>
                OsdPages.material(
                  state,
                  const ConfirmMoviePage(
                    key: ValueKey<AppRoute>(AppRoute.confirmMovie),
                  ),
                ),
          ),
          // Confirm → making → created each take the page's place with the
          // fade-through.
          GoRoute(
            path: AppRoute.makingMovie.pathBelow(AppRoute.createMovie),
            pageBuilder: (BuildContext context, GoRouterState state) =>
                OsdPages.fadeThrough(
                  state,
                  BlocProvider<ReportErrorCubit>(
                    create: (_) => sl<ReportErrorCubit>(),
                    child: const MakingMoviePage(
                      key: ValueKey<AppRoute>(AppRoute.makingMovie),
                    ),
                  ),
                ),
          ),
          GoRoute(
            path: AppRoute.movieCreated.pathBelow(AppRoute.createMovie),
            pageBuilder: (BuildContext context, GoRouterState state) =>
                OsdPages.fadeThrough(
                  state,
                  BlocProvider<MovieCreatedCubit>(
                    create: (BuildContext context) => sl<MovieCreatedCubit>(
                      param1: context.read<MovieJobBloc>().state,
                    ),
                    child: const MovieCreatedPage(
                      key: ValueKey<AppRoute>(AppRoute.movieCreated),
                    ),
                  ),
                ),
          ),
        ],
      ),
    ],
  ),
];

/// The movie the player opens, relative to `Movies/` (the `file` query
/// parameter, `MoviePlayerArgs`).
String? movieFileOf(GoRouterState state) =>
    state.uri.queryParameters[AppRoute.movieFileParameter];
