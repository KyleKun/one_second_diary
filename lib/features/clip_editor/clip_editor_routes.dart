import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/logging/bug_report_service.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/osd_pages.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/router/route_guards.dart';
import 'package:one_second_diary/features/clip_editor/data/filmstrip_frames.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/pages/edit_clip_page.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';

/// The clip editor, on the root navigator: `EditClipArgs(…).push<SavedClip>(context)`.
/// A recording enters with a fade-through (it takes the camera's place); a pick with the platform push.
List<RouteBase> clipEditorRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoute.editClip.path,
    redirect: requireArgs<EditClipArgs>(orElse: AppRoute.today),
    pageBuilder: (BuildContext context, GoRouterState state) {
      final EditClipArgs args = argsOf<EditClipArgs>(state);
      final Widget page = MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<PlayerPool>(
            create: (_) => sl<PlayerPool>(param1: true),
            dispose: (PlayerPool pool) => unawaited(pool.dispose()),
          ),
          RepositoryProvider<FilmstripFrames>(
            create: (_) => sl<FilmstripFrames>(),
            dispose: (FilmstripFrames frames) => unawaited(frames.dispose()),
          ),
          // "Report error" after a failed save; the container owns it.
          RepositoryProvider<BugReportService>.value(
            value: sl<BugReportService>(),
          ),
        ],
        child: BlocProvider<EditClipCubit>(
          create: (_) => sl<EditClipCubit>(param1: args),
          child: const EditClipPage(key: ValueKey<AppRoute>(AppRoute.editClip)),
        ),
      );
      return switch (args.source) {
        VideoSource(fromRecording: true) => OsdPages.fadeThrough(state, page),
        _ => OsdPages.material(state, page),
      };
    },
  ),
];
