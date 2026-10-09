import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:one_second_diary/features/clips/data/shown_player.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/viewer_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/pages/diary_page.dart';
import 'package:one_second_diary/features/diary/presentation/pages/viewer_page.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/theme/osd_forced_dark.dart';

/// The Diary tab, shell branch 1: the calendar and Memories, with the
/// tab's `DiaryCubit` and `PlayerPool`, which live as long as the tab. The
/// pool starts muted, its players mixing with the user's music, until the
/// sound toggle turns the sound on. Text is read in the page's `build`.
///
/// The branch is built with the shell, while hidden (`preload`): the
/// selected day's player opens at launch (alone: a hidden tab keeps no
/// neighbours warm), so the first visit plays it at once instead of
/// waiting for the decoder.
StatefulShellBranch diaryBranch() => StatefulShellBranch(
  preload: true,
  routes: <RouteBase>[
    GoRoute(
      path: AppRoute.diary.path,
      pageBuilder: (BuildContext context, GoRouterState state) =>
          OsdPages.material(
            state,
            RepositoryProvider<PlayerPool>(
              create: (_) => sl<PlayerPool>(param1: true),
              dispose: (PlayerPool pool) => unawaited(pool.dispose()),
              child: BlocProvider<DiaryCubit>(
                create: (_) => sl<DiaryCubit>(),
                child: const DiaryPage(key: ValueKey<AppRoute>(AppRoute.diary)),
              ),
            ),
          ),
    ),
  ],
);

/// The Diary's full-screen routes on the root navigator: the viewer
/// (always dark, and the one Diary page that turns sideways with the
/// phone), opened with `ViewerArgs(clip:).push<ClipRef>(context)`.
///
/// The clip flies in from where it was tapped (`OsdPages.mediaFlight`).
/// The viewer has its own `PlayerPool`, with the user's last sound choice
/// (`calendarAutoSound`, sound on by default), which adopts the opener's
/// warm player (`ViewerArgs.warmPlayer`), and its `ViewerCubit`.
List<RouteBase> diaryRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoute.viewer.path,
    redirect: requireArgs<ViewerArgs>(orElse: AppRoute.diary),
    pageBuilder: (BuildContext context, GoRouterState state) {
      final ViewerArgs args = argsOf<ViewerArgs>(state);
      return OsdPages.mediaFlight(
        state,
        OsdForcedDark(
          child: LandscapeWhileOpen(
            orientation: sl<ScreenOrientationGateway>(),
            child: RepositoryProvider<PlayerPool>(
              create: (_) => _viewerPool(args.warmPlayer),
              dispose: (PlayerPool pool) => unawaited(pool.dispose()),
              child: BlocProvider<ViewerCubit>(
                create: (_) => sl<ViewerCubit>(param1: args),
                child: const ViewerPage(
                  key: ValueKey<AppRoute>(AppRoute.viewer),
                ),
              ),
            ),
          ),
        ),
        fadeIn: _viewerFadeIn,
        reverseDuration: _viewerBack,
      );
    },
  ),
];

/// The viewer's pool, with the user's last sound choice; it adopts the
/// Diary's warm player of the clip it opens on, when there is one, so that
/// clip plays as soon as the flight lands.
PlayerPool _viewerPool(ShownPlayer? warmPlayer) {
  final PlayerPool pool = sl<PlayerPool>(
    param1: !sl<SettingsRepository>().calendarAutoSound.value,
  );
  if (warmPlayer != null) pool.adopt(warmPlayer);
  return pool;
}

/// The viewer's black page fades in over the flight's first 200 ms.
const Duration _viewerFadeIn = Duration(milliseconds: 200);

/// The flight back from the viewer.
const Duration _viewerBack = Duration(milliseconds: 260);
