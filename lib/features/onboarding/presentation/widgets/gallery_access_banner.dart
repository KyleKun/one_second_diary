import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/permissions/access_outcome.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_callout.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// Why onboarding wants the gallery, after the phone refused it (Android):
/// the inline explanation of what the access is for, and the way to give
/// it: "Allow access" asks again while the prompt can still show, "Open
/// settings" once only the system Settings can grant it. "Start my diary"
/// goes on without it.
///
/// It opens under the name field (the last thing above the button) and
/// scrolls itself into view; it closes once the access is granted in
/// Settings and the app is back.
class GalleryAccessBanner extends StatelessWidget {
  const GalleryAccessBanner({super.key});

  static const Key bannerKey = Key('galleryAccessBanner.banner');

  @override
  Widget build(BuildContext context) {
    final AccessOutcome? refused = context
        .select<OnboardingCubit, AccessOutcome?>(
          (OnboardingCubit cubit) =>
              cubit.state.status == OnboardingStatus.accessRefused
              ? cubit.state.access
              : null,
        );
    final OnboardingCubit cubit = context.read<OnboardingCubit>();
    // It fades in at its full size, so the scroll can bring all of it into
    // view at once (the scroll is the motion).
    return AnimatedSwitcher(
      duration: OsdMotion.d(context, OsdMotion.fast),
      switchInCurve: OsdMotion.fastCurve,
      switchOutCurve: OsdMotion.fastCurve,
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[...previous, ?current],
      ),
      child: refused == null
          ? const SizedBox(width: double.infinity)
          : _InView(
              key: bannerKey,
              child: Padding(
                padding: const EdgeInsets.only(bottom: OsdSpace.s24),
                child: OsdCallout.banner(
                  icon: OsdIcons.photoLibrary,
                  title: Strings.storagePermissionTitle,
                  text: Strings.storagePermissionBody,
                  actionLabel: refused == AccessOutcome.blocked
                      ? Strings.openSettings
                      : Strings.allowAccess,
                  onAction: refused == AccessOutcome.blocked
                      ? () => unawaited(cubit.openAccessSettings())
                      : () => unawaited(cubit.askAccessAgain()),
                ),
              ),
            ),
    );
  }
}

/// Scrolls its [child] into view when it first shows.
class _InView extends StatefulWidget {
  const _InView({super.key, required this.child});

  final Widget child;

  @override
  State<_InView> createState() => _InViewState();
}

class _InViewState extends State<_InView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          context,
          duration: OsdMotion.d(context, OsdMotion.standard),
          curve: OsdMotion.curve(context, OsdMotion.standardCurve),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
