import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/osd_pages.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/phone_check_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/onboarding_flow.dart';
import 'package:one_second_diary/features/onboarding/presentation/pages/onboarding_intro_page.dart';
import 'package:one_second_diary/features/onboarding/presentation/pages/onboarding_orientation_page.dart';
import 'package:one_second_diary/features/onboarding/presentation/pages/onboarding_permissions_page.dart';
import 'package:one_second_diary/features/onboarding/presentation/pages/phone_check_page.dart';

/// Onboarding, the only routes before onboarding is done (the router's
/// gate): a `ShellRoute` that gives one `OnboardingCubit` to the intro
/// carousel, to the orientation page the carousel pushes above itself, to
/// the permissions page pushed above that (or above the carousel on a
/// reinstall), and to the phone check pushed above the permissions page,
/// which finishes the flow. The flow ends with `AppRoute.today.go`, which
/// replaces the stack (`OnboardingFlow`).
///
/// [createCubit] makes the flow's cubit; the app's comes from the service
/// locator (page tests pass their own). [createPhoneCheck] makes the phone
/// check's cubit for the Default profile's orientation, likewise. Text is
/// read in the pages' `build`.
List<RouteBase> onboardingRoutes({
  OnboardingCubit Function()? createCubit,
  PhoneCheckCubit Function(VideoOrientation orientation)? createPhoneCheck,
}) => <RouteBase>[
  ShellRoute(
    pageBuilder: (BuildContext context, GoRouterState state, Widget child) =>
        OsdPages.material(
          state,
          BlocProvider<OnboardingCubit>(
            create: (_) => createCubit?.call() ?? sl<OnboardingCubit>(),
            child: OnboardingFlow(child: child),
          ),
        ),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.onboarding.path,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            OsdPages.material(
              state,
              const OnboardingIntroPage(
                key: ValueKey<AppRoute>(AppRoute.onboarding),
              ),
            ),
        routes: <RouteBase>[
          // The page has no visible back button; system back and the iOS
          // edge swipe return to the carousel.
          GoRoute(
            path: AppRoute.onboardingOrientation.pathBelow(AppRoute.onboarding),
            pageBuilder: (BuildContext context, GoRouterState state) =>
                OsdPages.material(
                  state,
                  const OnboardingOrientationPage(
                    key: ValueKey<AppRoute>(AppRoute.onboardingOrientation),
                  ),
                ),
          ),
          // Likewise: back returns to the orientation page (or the carousel).
          GoRoute(
            path: AppRoute.onboardingPermissions.pathBelow(AppRoute.onboarding),
            pageBuilder: (BuildContext context, GoRouterState state) =>
                OsdPages.material(
                  state,
                  const OnboardingPermissionsPage(
                    key: ValueKey<AppRoute>(AppRoute.onboardingPermissions),
                  ),
                ),
          ),
          // The phone check: back returns to the permissions page and
          // cancels the check. Its cubit is the page's own, for the canvas
          // chosen (landscape on a reinstall whose canvas is fixed: the
          // store keeps that one anyway).
          GoRoute(
            path: AppRoute.onboardingPhoneCheck.pathBelow(AppRoute.onboarding),
            pageBuilder: (BuildContext context, GoRouterState state) =>
                OsdPages.material(
                  state,
                  BlocProvider<PhoneCheckCubit>(
                    create: (BuildContext context) {
                      final VideoOrientation orientation =
                          context.read<OnboardingCubit>().state.orientation ??
                          VideoOrientation.landscape;
                      return createPhoneCheck?.call(orientation) ??
                          sl<PhoneCheckCubit>(param1: orientation);
                    },
                    child: const PhoneCheckPage(
                      key: ValueKey<AppRoute>(AppRoute.onboardingPhoneCheck),
                      mode: PhoneCheckMode.onboarding,
                    ),
                  ),
                ),
          ),
        ],
      ),
    ],
  ),
];
