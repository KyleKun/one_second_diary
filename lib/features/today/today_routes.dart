import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/osd_pages.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_character_cubit.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_cubit.dart';
import 'package:one_second_diary/features/today/presentation/pages/today_page.dart';

/// The Today tab, shell branch 0, and the app's initial location:
/// `TodayPage` with its `TodayCubit`, its `TodayCharacterCubit` (what the
/// character says, over the day's state) and its `PlayerPool` (the day's
/// clips play inline, with sound), which live as long as the tab (the
/// shell keeps its branch alive) and are closed with it.
StatefulShellBranch todayBranch() => StatefulShellBranch(
  routes: <RouteBase>[
    GoRoute(
      path: AppRoute.today.path,
      pageBuilder: (BuildContext context, GoRouterState state) =>
          OsdPages.material(
            state,
            RepositoryProvider<PlayerPool>(
              create: (_) => sl<PlayerPool>(param1: false),
              dispose: (PlayerPool pool) => unawaited(pool.dispose()),
              child: BlocProvider<TodayCubit>(
                create: (_) => sl<TodayCubit>(),
                child: BlocProvider<TodayCharacterCubit>(
                  create: (BuildContext context) => sl<TodayCharacterCubit>(
                    param1: context.read<TodayCubit>(),
                  ),
                  child: const TodayPage(key: TodayPage.pageKey),
                ),
              ),
            ),
          ),
    ),
  ],
);
