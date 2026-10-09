import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/phone_check_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/phone_check_state.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/gallery_access_dialog_listener.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/phone_check_progress.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/phone_check_result_card.dart';
import 'package:one_second_diary/features/profiles/domain/quality_recommender.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/quality_sheet.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/shared/widgets/foundation/snackbar_anchor.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_callout.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Where the phone check page sits.
enum PhoneCheckMode {
  /// After the permissions step: the result finishes onboarding
  /// ("Use this", "Choose another", "Skip").
  onboarding,

  /// Settings "Check again": the stored result, then a new run on demand.
  settings,
}

/// The phone check: "Checking your phone", a
/// progress bar over the tests, then the result card with the
/// recommended quality.
///
/// In [PhoneCheckMode.onboarding] "Use this" and "Choose another" (the
/// quality sheet) finish the diary with the format; "Skip" selects
/// Standard and lets the check finish in the background. System back
/// returns to the permissions step and cancels the check. In
/// [PhoneCheckMode.settings] the page opens on the stored result (or runs
/// when there is none) and "Check again" runs it anew. Reduced motion:
/// the bar jumps. The test label is a live region.
class PhoneCheckPage extends StatefulWidget {
  const PhoneCheckPage({super.key, required this.mode});

  static const Key useKey = Key('phoneCheck.use');
  static const Key chooseKey = Key('phoneCheck.choose');
  static const Key skipKey = Key('phoneCheck.skip');
  static const Key againKey = Key('phoneCheck.again');

  /// The widest the content gets, centred on tablets.
  static const double maxWidth = 480;

  /// The space above the title and under the buttons.
  static const double edgeGap = 34;

  final PhoneCheckMode mode;

  @override
  State<PhoneCheckPage> createState() => _PhoneCheckPageState();
}

class _PhoneCheckPageState extends State<PhoneCheckPage> {
  @override
  void initState() {
    super.initState();
    final PhoneCheckCubit check = context.read<PhoneCheckCubit>();
    switch (widget.mode) {
      case PhoneCheckMode.onboarding:
        unawaited(check.start());
      case PhoneCheckMode.settings:
        unawaited(_openStored(check));
    }
  }

  Future<void> _openStored(PhoneCheckCubit check) async {
    await check.loadStored();
    if (!mounted || check.state.status != PhoneCheckStatus.idle) return;
    await check.start();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = Scaffold(
      backgroundColor: context.colors.bg,
      appBar: widget.mode == PhoneCheckMode.settings
          ? OsdAppBar(title: Strings.phoneCheckBenchmark)
          : null,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: PhoneCheckPage.maxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    child: _Content(mode: widget.mode),
                  ),
                ),
                _Footer(mode: widget.mode),
              ],
            ),
          ),
        ),
      ),
    );
    if (widget.mode == PhoneCheckMode.settings) return body;
    return GalleryAccessDialogListener(child: _OnboardingBack(child: body));
  }
}

/// System back in onboarding: the check is cancelled and the permissions step
/// shows again, except while the diary is being made.
class _OnboardingBack extends StatelessWidget {
  const _OnboardingBack({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool busy = context.select<OnboardingCubit, bool>(
      (OnboardingCubit cubit) => cubit.state.isBusy,
    );
    return PopScope<Object?>(
      canPop: !busy,
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) return;
        unawaited(context.read<PhoneCheckCubit>().cancel());
        context.read<OnboardingCubit>().phoneCheckClosed();
      },
      child: child,
    );
  }
}

/// The title and why, the progress while running, the result after.
class _Content extends StatelessWidget {
  const _Content({required this.mode});

  final PhoneCheckMode mode;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final PhoneCheckState state = context.watch<PhoneCheckCubit>().state;
    final LocaleFormats formats = LocaleFormats.of(context);
    final QualityRecommendation? advice = state.recommendation;
    final ClipFormat? selected = state.selected;
    final String? checkedOn = state.profile == null
        ? null
        : Strings.phoneCheckLastRun(
            date: formats.date('yMMMd').format(state.profile!.checkedAt),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OsdSpace.textInset,
        PhoneCheckPage.edgeGap,
        OsdSpace.textInset,
        OsdSpace.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: OsdSpace.s22,
        children: <Widget>[
          if (mode == PhoneCheckMode.onboarding)
            Semantics(
              header: true,
              child: Text(
                Strings.phoneCheckTitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textScaler: OsdTextScale.scalerFor(
                  context,
                  OsdTextScaleRole.display,
                ),
                style: typography.title30Wrap.copyWith(color: colors.tx),
              ),
            )
          else
            Text(
              Strings.phoneCheckBenchmarkDescription,
              style: typography.body16Loose.copyWith(color: colors.mu),
            ),
          if (state.isRunning || state.status == PhoneCheckStatus.idle)
            OsdCard(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(OsdSpace.s16),
                child: PhoneCheckProgressBar(progress: state.progress),
              ),
            ),
          if (state.status == PhoneCheckStatus.failed)
            OsdCallout.neutral(
              text: Strings.phoneCheckFailed,
              kind: OsdCalloutKind.warning,
            ),
          if (state.status == PhoneCheckStatus.skipped)
            OsdCallout.neutral(text: Strings.phoneCheckSkipped),
          if (state.stale) OsdCallout.neutral(text: Strings.phoneCheckStale),
          if (advice != null && selected != null && !state.isRunning)
            PhoneCheckResultCard(
              recommendation: advice,
              selected: selected,
              note: mode == PhoneCheckMode.settings ? checkedOn : null,
            ),
        ],
      ),
    );
  }
}

/// The pinned buttons: in onboarding "Use this" / "Choose another" once there is
/// a result, "Skip" while the check runs; in Settings "Check again".
class _Footer extends StatelessWidget {
  const _Footer({required this.mode});

  final PhoneCheckMode mode;

  Future<void> _chooseAnother(BuildContext context) async {
    final PhoneCheckCubit check = context.read<PhoneCheckCubit>();
    final OnboardingCubit onboarding = context.read<OnboardingCubit>();
    final QualityRecommendation? advice = check.state.recommendation;
    final VideoOrientation? orientation = onboarding.state.orientation;
    if (advice == null) return;
    final ClipFormat? picked = await QualitySheet.show(
      context,
      orientation: orientation ?? advice.pick.orientation,
      recommendation: advice,
      selected: check.state.selected,
    );
    if (picked == null) return;
    check.select(picked);
    await onboarding.startDiary(format: picked);
  }

  @override
  Widget build(BuildContext context) {
    final (
      bool running,
      bool hasResult,
      ClipFormat? selected,
    ) = context.select<PhoneCheckCubit, (bool, bool, ClipFormat?)>(
      (PhoneCheckCubit cubit) =>
          (cubit.state.isRunning, cubit.state.hasResult, cubit.state.selected),
    );
    final List<Widget> buttons = switch (mode) {
      PhoneCheckMode.settings => <Widget>[
        PrimaryButton(
          key: PhoneCheckPage.againKey,
          label: Strings.phoneCheckRunAgain,
          icon: OsdIcons.speed,
          size: OsdButtonSize.large,
          loading: running,
          haptic: OsdHaptic.light,
          onPressed: running
              ? null
              : () => unawaited(context.read<PhoneCheckCubit>().start()),
        ),
      ],
      PhoneCheckMode.onboarding => <Widget>[
        if (hasResult && selected != null) ...<Widget>[
          _UseButton(format: selected),
          NeutralButton(
            key: PhoneCheckPage.chooseKey,
            label: Strings.phoneCheckChooseAnother,
            size: OsdButtonSize.large,
            onPressed: () => unawaited(_chooseAnother(context)),
          ),
        ],
        if (running)
          OsdTextButton(
            key: PhoneCheckPage.skipKey,
            label: Strings.phoneCheckSkip,
            tone: OsdTextButtonTone.muted,
            onPressed: () => context.read<PhoneCheckCubit>().skip(),
          ),
      ],
    };
    return ColoredBox(
      color: context.colors.bg,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          OsdSpace.textInset,
          0,
          OsdSpace.textInset,
          OsdSpace.bottomGap(context, PhoneCheckPage.edgeGap),
        ),
        child: SnackbarAnchor(
          gap: OsdSpace.snackbarAboveCta,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: OsdSpace.s12,
            children: buttons,
          ),
        ),
      ),
    );
  }
}

/// "Use this": finishes the diary with [format]; a spinner while it is
/// made.
class _UseButton extends StatelessWidget {
  const _UseButton({required this.format});

  final ClipFormat format;

  @override
  Widget build(BuildContext context) {
    final bool working = context.select<OnboardingCubit, bool>(
      (OnboardingCubit cubit) =>
          cubit.state.status == OnboardingStatus.finishing,
    );
    return PrimaryButton(
      key: PhoneCheckPage.useKey,
      label: Strings.phoneCheckUseThis,
      size: OsdButtonSize.large,
      loading: working,
      haptic: OsdHaptic.light,
      onPressed: () =>
          unawaited(context.read<OnboardingCubit>().startDiary(format: format)),
    );
  }
}
