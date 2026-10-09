import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/di/launch_core.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/osd_pages.dart';
import 'package:one_second_diary/features/reminders/presentation/cubit/reminder_settings_cubit.dart';
import 'package:one_second_diary/features/reminders/presentation/pages/reminders_page.dart';
import 'package:one_second_diary/features/settings/domain/settings_platform.dart';

/// The Notifications page, pushed from Settings, with its own reminder
/// settings cubit (it checks the permission as the page opens, without a
/// prompt).
List<RouteBase> remindersRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoute.notifications.path,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        OsdPages.material(
          state,
          BlocProvider<ReminderSettingsCubit>(
            create: (_) {
              final ReminderSettingsCubit cubit = sl<ReminderSettingsCubit>();
              unawaited(cubit.checkAccess());
              return cubit;
            },
            child: RemindersPage(
              key: const ValueKey<AppRoute>(AppRoute.notifications),
              platform: SettingsPlatform(isIOS: sl<LaunchCore>().isIOS),
            ),
          ),
        ),
  ),
];
