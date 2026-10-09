import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/osd_pages.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/found_profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/pages/profile_list_page.dart';

/// The profiles page, pushed from Settings. The edit and new profile forms
/// are sheets, not routes, opened with `ProfileSheets`.
///
/// The list itself comes from the app-scoped `ProfilesCubit`; the page's
/// own cubit reads the folders "Found on this phone" as it opens.
List<RouteBase> profilesRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoute.profiles.path,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        OsdPages.material(
          state,
          BlocProvider<FoundProfilesCubit>(
            create: (_) {
              final FoundProfilesCubit cubit = sl<FoundProfilesCubit>();
              unawaited(cubit.load());
              return cubit;
            },
            child: const ProfileListPage(
              key: ValueKey<AppRoute>(AppRoute.profiles),
            ),
          ),
        ),
  ),
];
