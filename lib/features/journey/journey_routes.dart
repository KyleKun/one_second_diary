import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/osd_pages.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/router/route_guards.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/diary/presentation/diary_opener.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/journey_cubit.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/places_map_cubit.dart';
import 'package:one_second_diary/features/journey/presentation/pages/journey_page.dart';
import 'package:one_second_diary/features/journey/presentation/pages/place_clips_page.dart';
import 'package:one_second_diary/features/journey/presentation/pages/places_list_page.dart';
import 'package:one_second_diary/features/journey/presentation/pages/places_map_page.dart';
import 'package:one_second_diary/features/movies/data/movie_posters.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/theme/osd_forced_dark.dart';

/// The Journey tab, shell branch 2: the page with its `JourneyCubit`,
/// which lives as long as the tab, the app's `DiaryOpener`, through
/// which its tiles open the Diary, and the `MoviePosters` its My movies
/// row draws.
StatefulShellBranch journeyBranch() => StatefulShellBranch(
  routes: <RouteBase>[
    GoRoute(
      path: AppRoute.journey.path,
      pageBuilder: (BuildContext context, GoRouterState state) =>
          OsdPages.material(
            state,
            MultiRepositoryProvider(
              providers: <RepositoryProvider<Object>>[
                RepositoryProvider<DiaryOpener>.value(value: sl<DiaryOpener>()),
                RepositoryProvider<MoviePosters>.value(
                  value: sl<MoviePosters>(),
                ),
              ],
              child: BlocProvider<JourneyCubit>(
                create: (_) => sl<JourneyCubit>(),
                child: const JourneyPage(
                  key: ValueKey<AppRoute>(AppRoute.journey),
                ),
              ),
            ),
          ),
    ),
  ],
);

/// The Journey's full-screen routes on the root navigator: Places (the
/// globe, with its `PlacesMapCubit`), its full list of countries or places
/// (`PlacesListArgs(…).push(context)`, pops with the pick) and the clips of
/// one place (always dark, with its own `PlayerPool` in the user's last
/// sound choice, opened with `PlaceClipsArgs(…).push(context)`).
List<RouteBase> journeyRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoute.placesMap.path,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        OsdPages.material(
          state,
          RepositoryProvider<DiaryOpener>.value(
            value: sl<DiaryOpener>(),
            child: BlocProvider<PlacesMapCubit>(
              create: (_) => sl<PlacesMapCubit>(),
              child: const PlacesMapPage(
                key: ValueKey<AppRoute>(AppRoute.placesMap),
              ),
            ),
          ),
        ),
  ),
  GoRoute(
    path: AppRoute.placesList.path,
    redirect: requireArgs<PlacesListArgs>(orElse: AppRoute.placesMap),
    pageBuilder: (BuildContext context, GoRouterState state) =>
        OsdPages.material(
          state,
          PlacesListPage(
            key: const ValueKey<AppRoute>(AppRoute.placesList),
            args: argsOf<PlacesListArgs>(state),
          ),
        ),
  ),
  GoRoute(
    path: AppRoute.placeClips.path,
    redirect: requireArgs<PlaceClipsArgs>(orElse: AppRoute.journey),
    pageBuilder: (BuildContext context, GoRouterState state) =>
        OsdPages.material(
          state,
          OsdForcedDark(
            child: MultiRepositoryProvider(
              providers: <RepositoryProvider<Object>>[
                RepositoryProvider<DiaryOpener>.value(value: sl<DiaryOpener>()),
                RepositoryProvider<ClipMetadataCache>.value(
                  value: sl<ClipMetadataCache>(),
                ),
                RepositoryProvider<SettingsRepository>.value(
                  value: sl<SettingsRepository>(),
                ),
                RepositoryProvider<AppLogger>.value(value: sl<AppLogger>()),
                RepositoryProvider<PlayerPool>(
                  create: (_) => sl<PlayerPool>(
                    param1: !sl<SettingsRepository>().calendarAutoSound.value,
                  ),
                  dispose: (PlayerPool pool) => unawaited(pool.dispose()),
                ),
              ],
              child: PlaceClipsPage(
                key: const ValueKey<AppRoute>(AppRoute.placeClips),
                args: argsOf<PlaceClipsArgs>(state),
              ),
            ),
          ),
        ),
  ),
];
