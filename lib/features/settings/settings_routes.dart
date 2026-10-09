import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/di/launch_core.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/osd_pages.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/phone_check_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/pages/phone_check_page.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/reminders/presentation/cubit/reminder_settings_cubit.dart';
import 'package:one_second_diary/features/settings/domain/settings_platform.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/about_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/changelog_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/contact_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/link_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/places_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/preferences_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/tags_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/thanks_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/pages/about_page.dart';
import 'package:one_second_diary/features/settings/presentation/pages/app_licenses_page.dart';
import 'package:one_second_diary/features/settings/presentation/pages/app_preferences_page.dart';
import 'package:one_second_diary/features/settings/presentation/pages/changelog_page.dart';
import 'package:one_second_diary/features/settings/presentation/pages/places_page.dart';
import 'package:one_second_diary/features/settings/presentation/pages/settings_tab_page.dart';
import 'package:one_second_diary/features/settings/presentation/pages/support_page.dart';
import 'package:one_second_diary/features/settings/presentation/pages/tags_page.dart';
import 'package:one_second_diary/features/settings/presentation/pages/thanks_page.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/backup_sheet_cubit.dart';

/// The Settings tab, shell branch 3. Its pages are top-level routes on the
/// root navigator, so pushing one never switches the tab below it.
///
/// The tab's cubits live as long as the tab. The reminder permission is
/// checked once the tab shows, never before the first frame (the branch is
/// built on its first visit).
StatefulShellBranch settingsBranch() => StatefulShellBranch(
  routes: <RouteBase>[
    GoRoute(
      path: AppRoute.settings.path,
      pageBuilder: (BuildContext context, GoRouterState state) =>
          OsdPages.material(
            state,
            MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<SettingsCubit>(
                  create: (_) {
                    final SettingsCubit cubit = sl<SettingsCubit>();
                    unawaited(cubit.loadVersion());
                    return cubit;
                  },
                ),
                BlocProvider<ContactCubit>(create: (_) => sl<ContactCubit>()),
                BlocProvider<LinkCubit>(create: (_) => sl<LinkCubit>()),
                BlocProvider<ReminderSettingsCubit>(
                  create: (_) {
                    final ReminderSettingsCubit cubit =
                        sl<ReminderSettingsCubit>();
                    unawaited(cubit.checkAccess());
                    return cubit;
                  },
                ),
                BlocProvider<TagsCubit>(create: (_) => sl<TagsCubit>()..load()),
                BlocProvider<PlacesCubit>(
                  create: (_) => sl<PlacesCubit>()..load(),
                ),
                BlocProvider<BackupSheetCubit>(
                  create: (_) => sl<BackupSheetCubit>(),
                ),
              ],
              child: SettingsTabPage(
                key: const ValueKey<AppRoute>(AppRoute.settings),
                platform: SettingsPlatform(isIOS: sl<LaunchCore>().isIOS),
              ),
            ),
          ),
    ),
  ],
);

/// The pages pushed from the Settings tab. Support is a full-screen dialog
/// that closes instead of going back.
List<RouteBase> settingsRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoute.tags.path,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        OsdPages.material(
          state,
          BlocProvider<TagsCubit>(
            create: (_) => sl<TagsCubit>()..load(),
            child: const TagsPage(key: ValueKey<AppRoute>(AppRoute.tags)),
          ),
        ),
  ),
  GoRoute(
    path: AppRoute.places.path,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        OsdPages.material(
          state,
          BlocProvider<PlacesCubit>(
            create: (_) => sl<PlacesCubit>()..load(),
            child: const PlacesPage(key: ValueKey<AppRoute>(AppRoute.places)),
          ),
        ),
  ),
  GoRoute(
    path: AppRoute.preferences.path,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        OsdPages.material(
          state,
          BlocProvider<PreferencesCubit>(
            create: (_) {
              final PreferencesCubit cubit = sl<PreferencesCubit>();
              unawaited(cubit.load());
              return cubit;
            },
            child: const AppPreferencesPage(
              key: ValueKey<AppRoute>(AppRoute.preferences),
            ),
          ),
        ),
  ),
  GoRoute(
    path: AppRoute.phoneCheck.path,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        OsdPages.material(
          state,
          BlocProvider<PhoneCheckCubit>(
            create: (_) => sl<PhoneCheckCubit>(
              param1: sl<ProfilesRepository>().active.orientation,
            ),
            child: const PhoneCheckPage(
              key: ValueKey<AppRoute>(AppRoute.phoneCheck),
              mode: PhoneCheckMode.settings,
            ),
          ),
        ),
  ),
  GoRoute(
    path: AppRoute.about.path,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        OsdPages.material(
          state,
          MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<AboutCubit>(create: (_) => _aboutCubit()),
              BlocProvider<BackupSheetCubit>(
                create: (_) => sl<BackupSheetCubit>(),
              ),
            ],
            child: AboutPage(
              key: const ValueKey<AppRoute>(AppRoute.about),
              platform: SettingsPlatform(isIOS: sl<LaunchCore>().isIOS),
            ),
          ),
        ),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.changelog.pathBelow(AppRoute.about),
        pageBuilder: (BuildContext context, GoRouterState state) =>
            OsdPages.material(
              state,
              BlocProvider<ChangelogCubit>(
                create: (_) {
                  final ChangelogCubit cubit = sl<ChangelogCubit>();
                  unawaited(cubit.load());
                  return cubit;
                },
                child: const ChangelogPage(
                  key: ValueKey<AppRoute>(AppRoute.changelog),
                ),
              ),
            ),
      ),
      GoRoute(
        path: AppRoute.thanks.pathBelow(AppRoute.about),
        pageBuilder: (BuildContext context, GoRouterState state) =>
            OsdPages.material(
              state,
              MultiBlocProvider(
                providers: <BlocProvider<dynamic>>[
                  BlocProvider<ThanksCubit>(
                    create: (_) {
                      final ThanksCubit cubit = sl<ThanksCubit>();
                      unawaited(cubit.load());
                      return cubit;
                    },
                  ),
                  BlocProvider<LinkCubit>(create: (_) => sl<LinkCubit>()),
                ],
                child: const ThanksPage(
                  key: ValueKey<AppRoute>(AppRoute.thanks),
                ),
              ),
            ),
      ),
      GoRoute(
        path: AppRoute.licenses.pathBelow(AppRoute.about),
        pageBuilder: (BuildContext context, GoRouterState state) =>
            OsdPages.material(
              state,
              BlocProvider<AboutCubit>(
                create: (_) => _aboutCubit(),
                child: const AppLicensesPage(
                  key: ValueKey<AppRoute>(AppRoute.licenses),
                ),
              ),
            ),
      ),
    ],
  ),
  GoRoute(
    path: AppRoute.support.path,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        OsdPages.material(
          state,
          BlocProvider<LinkCubit>(
            create: (_) => sl<LinkCubit>(),
            child: SupportPage(
              key: const ValueKey<AppRoute>(AppRoute.support),
              platform: SettingsPlatform(isIOS: sl<LaunchCore>().isIOS),
            ),
          ),
          fullscreenDialog: true,
        ),
  ),
];

/// About's cubit, reading the version as the page opens.
AboutCubit _aboutCubit() {
  final AboutCubit cubit = sl<AboutCubit>();
  unawaited(cubit.loadVersion());
  return cubit;
}
