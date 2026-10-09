import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/app_shell.dart';
import 'package:one_second_diary/core/router/osd_pages.dart';
import 'package:one_second_diary/core/router/shell_branch_stack.dart';
import 'package:one_second_diary/features/clip_editor/clip_editor_routes.dart';
import 'package:one_second_diary/features/diary/diary_routes.dart';
import 'package:one_second_diary/features/journey/journey_routes.dart';
import 'package:one_second_diary/features/movies/movies_routes.dart';
import 'package:one_second_diary/features/onboarding/onboarding_routes.dart';
import 'package:one_second_diary/features/profiles/profiles_routes.dart';
import 'package:one_second_diary/features/recording/recording_routes.dart';
import 'package:one_second_diary/features/reminders/reminders_routes.dart';
import 'package:one_second_diary/features/settings/settings_routes.dart';
import 'package:one_second_diary/features/today/today_routes.dart';

/// The app's routes, composed from each feature's
/// `lib/features/<f>/<f>_routes.dart`. This file owns only what no feature
/// owns: the onboarding gate and the shell.
///
/// - **Onboarding gate**, the only global redirect: the diary is onboarded
///   if and only if [isOnboarded] (`showIntro == false`; absent means not).
///   Until then every location leads into `/onboarding`; after it, every
///   onboarding location leads to Today.
/// - **Shell:** a `StatefulShellRoute` with the four tabs, each on its own
///   navigator, kept alive while hidden ([ShellBranchStack], [AppShell]).
///   Its page fades through when it takes onboarding's place; pages pushed
///   above it move it as usual.
/// - **Full-screen routes** on the root navigator, above the shell and its
///   nav, always pushed. The `/settings/…` pages are top-level routes: they
///   don't match the `/settings` branch, which has no sub-routes, so they
///   never switch the tab below them (verified in `app_router_test.dart`).
/// - **Typed arguments** (`RouteArgs`) travel as `extra`, and a route that
///   needs them only opens through `RouteArgs.push` (`AppRoute.push`
///   refuses it). Each route's `redirect` checks the type too, as the last
///   resort for a location without them (a deep link, a restored
///   location): it replaces the stack with a safe tab, so no builder casts.
///   Inside a push it would put that tab into the current one, which is why
///   pushes never rely on it.
/// - **Pages** are built by `OsdPages` (never a plain `builder:`), so pushes
///   and pops use the theme's transitions: the platform's (with the iOS back
///   swipe), or a 150 ms crossfade under reduced motion.
///
/// Builders must not read `Strings` themselves: a page built from a builder
/// is not rebuilt with new arguments after a language change, so text is
/// read in the page's own `build`.
GoRouter buildAppRouter({required bool Function() isOnboarded}) => GoRouter(
  initialLocation: AppRoute.today.path,
  redirect: (BuildContext context, GoRouterState state) =>
      _onboardingGate(state, onboarded: isOnboarded()),
  routes: <RouteBase>[
    ...onboardingRoutes(),
    StatefulShellRoute(
      pageBuilder:
          (
            BuildContext context,
            GoRouterState state,
            StatefulNavigationShell navigationShell,
          ) => OsdPages.fadeThrough(
            state,
            AppShell(navigationShell: navigationShell),
          ),
      navigatorContainerBuilder:
          (
            BuildContext context,
            StatefulNavigationShell navigationShell,
            List<Widget> children,
          ) => ShellBranchStack(
            index: navigationShell.currentIndex,
            children: children,
          ),
      branches: <StatefulShellBranch>[
        todayBranch(),
        diaryBranch(),
        journeyBranch(),
        settingsBranch(),
      ],
    ),
    ...recordingRoutes(),
    ...clipEditorRoutes(),
    ...diaryRoutes(),
    ...journeyRoutes(),
    ...moviesRoutes(),
    ...remindersRoutes(),
    ...profilesRoutes(),
    ...settingsRoutes(),
  ],
);

/// The intro until `showIntro == false`.
String? _onboardingGate(GoRouterState state, {required bool onboarded}) {
  final String path = state.uri.path;
  final bool atOnboarding =
      path == AppRoute.onboarding.path ||
      path.startsWith('${AppRoute.onboarding.path}/');
  if (!onboarded) return atOnboarding ? null : AppRoute.onboarding.path;
  return atOnboarding ? AppRoute.today.path : null;
}
