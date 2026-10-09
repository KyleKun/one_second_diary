import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/osd_pages.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/router/route_guards.dart';
import 'package:one_second_diary/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:one_second_diary/features/recording/presentation/camera_motion.dart';
import 'package:one_second_diary/features/recording/presentation/pages/camera_page.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_keep_awake.dart';
import 'package:one_second_diary/features/settings/presentation/report_error/report_error_cubit.dart';
import 'package:one_second_diary/theme/osd_forced_dark.dart';

/// The camera, always dark, on the root navigator, opened with
/// `RecordArgs(day:, profile:, mode:).push<SavedClip>(context)`. When the
/// recording is done it hands over to the clip editor with
/// `EditClipArgs(…).pushReplacement(context)`, so the `SavedClip` reaches
/// whoever opened the camera.
///
/// It is a media-flight page: Today's record button flies into the shutter
/// (`HeroTags.recordShutter`). The page's [RecordingBloc] starts at once and
/// the screen stays awake while it shows ([CameraKeepAwake]).
List<RouteBase> recordingRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoute.record.path,
    redirect: requireArgs<RecordArgs>(orElse: AppRoute.today),
    pageBuilder: (BuildContext context, GoRouterState state) =>
        OsdPages.mediaFlight(
          state,
          duration: CameraMotion.enter,
          OsdForcedDark(
            child: CameraKeepAwake(
              wakelock: sl(),
              child: MultiBlocProvider(
                providers: <BlocProvider<Object?>>[
                  BlocProvider<RecordingBloc>(
                    create: (_) =>
                        sl<RecordingBloc>(param1: argsOf<RecordArgs>(state))
                          ..add(const RecordingStarted()),
                  ),
                  BlocProvider<ReportErrorCubit>(
                    create: (_) => sl<ReportErrorCubit>(),
                  ),
                ],
                child: const CameraPage(
                  key: ValueKey<AppRoute>(AppRoute.record),
                ),
              ),
            ),
          ),
        ),
  ),
];
