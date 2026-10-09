import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';

/// What the onboarding pages share around them, below the flow's
/// `OnboardingCubit`: the snackbar host and the flow's navigation, which
/// follows the cubit's transitions:
/// - the intro left → the orientation page is pushed above the carousel;
/// - the orientation confirmed (or the canvas already decided) → the
///   permissions page is pushed above;
/// - the permissions step continued → the phone check page is pushed
///   above;
/// - the diary made → Today, replacing the whole stack (`AppRoute.go`), so
///   back never returns to onboarding;
/// - a write refused → the error snackbar with "Try again", above the
///   page's button when it has one;
/// - the app back from the system Settings → the permissions step's rows,
///   and a refused gallery access, are checked again.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.child});

  /// The flow's navigator (the intro, and the orientation and permissions
  /// pages above it).
  final Widget child;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from the system Settings, access refused before may be granted.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        final OnboardingCubit cubit = context.read<OnboardingCubit>();
        unawaited(cubit.recheckAccess());
        unawaited(cubit.recheckPermissions());
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OsdSnackbarHost(
    child: MultiBlocListener(
      listeners: <BlocListener<OnboardingCubit, OnboardingState>>[
        // Back from the permissions step also lands on the orientation
        // step, without a push: the page is still there below.
        BlocListener<OnboardingCubit, OnboardingState>(
          listenWhen: (OnboardingState before, OnboardingState now) =>
              before.step == OnboardingStep.intro &&
              now.step == OnboardingStep.orientation,
          listener: (BuildContext context, _) =>
              unawaited(AppRoute.onboardingOrientation.push<void>(context)),
        ),
        BlocListener<OnboardingCubit, OnboardingState>(
          listenWhen: (OnboardingState before, OnboardingState now) =>
              before.step != now.step && now.step == OnboardingStep.permissions,
          listener: (BuildContext context, _) =>
              unawaited(AppRoute.onboardingPermissions.push<void>(context)),
        ),
        // Back from the phone check lands on the permissions step, which is
        // still there below.
        BlocListener<OnboardingCubit, OnboardingState>(
          listenWhen: (OnboardingState before, OnboardingState now) =>
              before.step == OnboardingStep.permissions &&
              now.step == OnboardingStep.phoneCheck,
          listener: (BuildContext context, _) =>
              unawaited(AppRoute.onboardingPhoneCheck.push<void>(context)),
        ),
        BlocListener<OnboardingCubit, OnboardingState>(
          listenWhen: (OnboardingState before, OnboardingState now) =>
              before.status != now.status &&
              now.status == OnboardingStatus.done,
          listener: (BuildContext context, _) => AppRoute.today.go(context),
        ),
        BlocListener<OnboardingCubit, OnboardingState>(
          listenWhen: (OnboardingState before, OnboardingState now) =>
              before.status != now.status &&
              now.status == OnboardingStatus.failed,
          listener: (BuildContext context, _) {
            final OnboardingCubit cubit = context.read<OnboardingCubit>();
            OsdSnackbar.show(
              context,
              kind: OsdSnackKind.error,
              title: Strings.onboardingSetupError,
              actionLabel: Strings.commonTryAgain,
              onAction: cubit.continueSetup,
            );
          },
        ),
      ],
      child: widget.child,
    ),
  );
}
