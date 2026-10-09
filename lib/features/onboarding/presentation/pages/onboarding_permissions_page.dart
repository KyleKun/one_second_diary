import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/onboarding/domain/onboarding_permission.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:one_second_diary/features/onboarding/presentation/onboarding_motion.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/gallery_access_dialog_listener.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/onboarding_rise.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/permission_setup_row.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/permissions_progress.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/foundation/snackbar_anchor.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The permissions step, "Allow access": one row per permission the
/// app uses on this phone, each with its own "Allow" and live state, so
/// the user enters the app with everything granted; then "Continue" to
/// the phone check, which goes on whatever was allowed.
///
/// The content scrolls under the pinned button when it is taller than the
/// screen, with a hairline above the button then. System back and the iOS
/// edge swipe return to the orientation step (or the intro on a
/// reinstall), except while the diary is being made. A gallery refused as
/// the diary is made (its row was never tapped) is explained in a dialog.
class OnboardingPermissionsPage extends StatefulWidget {
  const OnboardingPermissionsPage({super.key});

  static const Key startKey = Key('onboardingPermissions.start');

  static const Key dividerKey = Key('onboardingPermissions.divider');

  /// The widest the content gets, centred on tablets.
  static const double maxWidth = 480;

  /// The space above the title and under the button (the button's is
  /// `OsdSpace.bottomGap`'s base).
  static const double edgeGap = 34;

  @override
  State<OnboardingPermissionsPage> createState() =>
      _OnboardingPermissionsPageState();
}

class _OnboardingPermissionsPageState extends State<OnboardingPermissionsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: OnboardingRise.total,
  );

  /// Whether the content is taller than the space above the button.
  bool _scrolls = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance.isAnimating || _entrance.value > 0) return;
    if (OsdMotion.reduced(context)) {
      _entrance.value = 1;
    } else {
      unawaited(_entrance.forward());
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    final bool scrolls = notification.metrics.maxScrollExtent > 0;
    if (scrolls != _scrolls) setState(() => _scrolls = scrolls);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = context.select<OnboardingCubit, bool>(
      (OnboardingCubit cubit) => cubit.state.isBusy,
    );
    return GalleryAccessDialogListener(
      child: PopScope<Object?>(
        canPop: !busy,
        onPopInvokedWithResult: (bool didPop, _) {
          if (didPop) context.read<OnboardingCubit>().permissionsClosed();
        },
        child: Scaffold(
          backgroundColor: context.colors.bg,
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: OnboardingPermissionsPage.maxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: NotificationListener<ScrollMetricsNotification>(
                        onNotification: _onMetrics,
                        child: SingleChildScrollView(
                          child: _Content(entrance: _entrance),
                        ),
                      ),
                    ),
                    _Footer(entrance: _entrance, divided: _scrolls),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What scrolls, top to bottom: the title and why, the card of rows, and
/// how many are allowed.
class _Content extends StatelessWidget {
  const _Content({required this.entrance});

  final Animation<double> entrance;

  @override
  Widget build(BuildContext context) {
    // The map is replaced only when a row changes.
    final List<OnboardingPermission> rows = context
        .select<
          OnboardingCubit,
          Map<OnboardingPermission, PermissionRowStatus>
        >((OnboardingCubit cubit) => cubit.state.permissions)
        .keys
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OnboardingRise(
          entrance: entrance,
          delay: Duration.zero,
          length: OnboardingMotion.textIn,
          rise: OnboardingMotion.textRise,
          child: const _Title(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OsdSpace.textInset,
            OsdSpace.s22,
            OsdSpace.textInset,
            0,
          ),
          child: OsdCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final (int i, OnboardingPermission row)
                    in rows.indexed) ...[
                  if (i > 0) const OsdDivider(),
                  OnboardingRise(
                    entrance: entrance,
                    delay:
                        OnboardingMotion.tilesDelay +
                        OnboardingMotion.tileStagger * i,
                    length: OnboardingMotion.tileIn,
                    rise: OnboardingMotion.tileRise,
                    child: _Row(permission: row),
                  ),
                ],
              ],
            ),
          ),
        ),
        OnboardingRise(
          entrance: entrance,
          delay: OnboardingMotion.closingDelay,
          length: OnboardingMotion.tileIn,
          rise: 0,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(
              OsdSpace.textInset,
              OsdSpace.s16,
              OsdSpace.textInset,
              OsdSpace.s24,
            ),
            child: _Progress(),
          ),
        ),
      ],
    );
  }
}

/// "Allow access" and why now.
class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OsdSpace.onboardingTextInset,
        OnboardingPermissionsPage.edgeGap,
        OsdSpace.onboardingTextInset,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: OsdSpace.s12,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              Strings.onboardingPermissionsTitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textScaler: OsdTextScale.scalerFor(
                context,
                OsdTextScaleRole.display,
              ),
              style: typography.title30Wrap.copyWith(color: colors.tx),
            ),
          ),
          Text(
            Strings.onboardingPermissionsBody,
            style: typography.body16Loose.copyWith(color: colors.mu),
          ),
        ],
      ),
    );
  }
}

/// A permission's row: rebuilt only when its own state changes.
class _Row extends StatelessWidget {
  const _Row({required this.permission});

  final OnboardingPermission permission;

  @override
  Widget build(BuildContext context) {
    final PermissionRowStatus status = context
        .select<OnboardingCubit, PermissionRowStatus>(
          (OnboardingCubit cubit) =>
              cubit.state.permissions[permission] ??
              PermissionRowStatus.notAsked,
        );
    final OnboardingCubit cubit = context.read<OnboardingCubit>();
    return PermissionSetupRow(
      permission: permission,
      status: status,
      onAllow: () => unawaited(cubit.allow(permission)),
      onOpenSettings: () => unawaited(cubit.openAccessSettings()),
    );
  }
}

/// "{granted} of {total} allowed", or "You're all set".
class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) {
    final (int granted, int total) = context
        .select<OnboardingCubit, (int, int)>(
          (OnboardingCubit cubit) =>
              (cubit.state.grantedCount, cubit.state.permissions.length),
        );
    return PermissionsProgress(granted: granted, total: total);
  }
}

/// The pinned bottom: a hairline while the content scrolls under it
/// ([divided]), then "Start my diary", which the setup error's snackbar
/// sits above.
class _Footer extends StatelessWidget {
  const _Footer({required this.entrance, required this.divided});

  final Animation<double> entrance;
  final bool divided;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.colors.bg,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Visibility.maintain(
          visible: divided,
          child: const OsdDivider.full(
            key: OnboardingPermissionsPage.dividerKey,
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            OsdSpace.textInset,
            0,
            OsdSpace.textInset,
            OsdSpace.bottomGap(context, OnboardingPermissionsPage.edgeGap),
          ),
          child: OnboardingRise(
            entrance: entrance,
            delay: OnboardingMotion.closingDelay,
            length: OnboardingMotion.tileIn,
            rise: 0,
            child: const SnackbarAnchor(
              gap: OsdSpace.snackbarAboveCta,
              child: _StartButton(),
            ),
          ),
        ),
      ],
    ),
  );
}

/// "Continue": always on (nothing is required); opens the phone check
/// which finishes the diary. A spinner while the diary is being
/// made ("Try again" after a failure runs the finish from here too).
class _StartButton extends StatelessWidget {
  const _StartButton();

  @override
  Widget build(BuildContext context) {
    final bool working = context.select<OnboardingCubit, bool>(
      (OnboardingCubit cubit) =>
          cubit.state.status == OnboardingStatus.finishing,
    );
    return PrimaryButton(
      key: OnboardingPermissionsPage.startKey,
      label: Strings.onboardingContinue,
      size: OsdButtonSize.large,
      loading: working,
      haptic: OsdHaptic.light,
      onPressed: () => context.read<OnboardingCubit>().goToPhoneCheck(),
    );
  }
}
