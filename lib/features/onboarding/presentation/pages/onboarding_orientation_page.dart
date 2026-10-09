import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:one_second_diary/features/onboarding/presentation/onboarding_motion.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/gallery_access_banner.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/onboarding_name_field.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/onboarding_rise.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/orientation_tip_card.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/controls/orientation_option_tile.dart';
import 'package:one_second_diary/shared/widgets/foundation/fade_on_enable.dart';
import 'package:one_second_diary/shared/widgets/foundation/snackbar_anchor.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The orientation step, "Where will you watch your movie?": the Default
/// profile's shape, Landscape 16:9 or Portrait 9:16, which never changes
/// afterwards; the optional name; "Continue", to the permissions step.
///
/// Nothing is picked at first, and "Continue" stays off until the user
/// taps a shape. The content scrolls under the pinned button when it is
/// taller than the screen, with a hairline above the button then. System
/// back and the iOS edge swipe return to the intro, except while the diary
/// is being made (the gallery refused at the finish is explained inline
/// here, as the fallback of the permissions step).
class OnboardingOrientationPage extends StatefulWidget {
  const OnboardingOrientationPage({super.key});

  static Key tileKey(VideoOrientation orientation) =>
      ValueKey<(String, VideoOrientation)>((
        'onboardingOrientation.tile',
        orientation,
      ));

  static const Key continueKey = Key('onboardingOrientation.continue');

  static const Key dividerKey = Key('onboardingOrientation.divider');

  /// The widest the content gets, centred on tablets.
  static const double maxWidth = 480;

  /// The space above the title and under the button (the button's is
  /// `OsdSpace.bottomGap`'s base).
  static const double edgeGap = 34;

  @override
  State<OnboardingOrientationPage> createState() =>
      _OnboardingOrientationPageState();
}

class _OnboardingOrientationPageState extends State<OnboardingOrientationPage>
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
    return PopScope<Object?>(
      canPop: !busy,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) context.read<OnboardingCubit>().orientationClosed();
      },
      child: Scaffold(
        backgroundColor: context.colors.bg,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: OnboardingOrientationPage.maxWidth,
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
    );
  }
}

/// What scrolls, top to bottom: the question, the tip card, the two
/// shapes, the name, and the gallery explanation when it shows.
class _Content extends StatelessWidget {
  const _Content({required this.entrance});

  final Animation<double> entrance;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      OnboardingRise(
        entrance: entrance,
        delay: Duration.zero,
        length: OnboardingMotion.textIn,
        rise: OnboardingMotion.textRise,
        child: const _Question(),
      ),
      OnboardingRise(
        entrance: entrance,
        delay: OnboardingMotion.tipDelay,
        length: OnboardingMotion.textIn,
        rise: 0,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(
            OsdSpace.textInset,
            OsdSpace.s22,
            OsdSpace.textInset,
            0,
          ),
          child: OrientationTipCard(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          OsdSpace.textInset,
          OsdSpace.s16,
          OsdSpace.textInset,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: OsdSpace.s12,
          children: <Widget>[
            for (final (int i, VideoOrientation orientation)
                in VideoOrientation.values.indexed)
              OnboardingRise(
                entrance: entrance,
                delay:
                    OnboardingMotion.tilesDelay +
                    OnboardingMotion.tileStagger * i,
                length: OnboardingMotion.tileIn,
                rise: OnboardingMotion.tileRise,
                child: _Tile(orientation: orientation),
              ),
          ],
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
            OsdSpace.s22,
            OsdSpace.textInset,
            OsdSpace.s24,
          ),
          child: OnboardingNameField(),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: OsdSpace.textInset),
        child: GalleryAccessBanner(),
      ),
    ],
  );
}

/// "Where will you watch your movie?" and what the choice sets.
class _Question extends StatelessWidget {
  const _Question();

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OsdSpace.onboardingTextInset,
        OnboardingOrientationPage.edgeGap,
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
              Strings.onboardingOrientationQuestion,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textScaler: OsdTextScale.scalerFor(
                context,
                OsdTextScaleRole.display,
              ),
              style: typography.title30Wrap.copyWith(color: colors.tx),
            ),
          ),
          // The body and the footnote are one string.
          Text(
            Strings.onboardingOrientationDesc,
            style: typography.body16Loose.copyWith(color: colors.mu),
          ),
        ],
      ),
    );
  }
}

/// The pinned bottom: a hairline while the content scrolls under it
/// ([divided]), then "Continue", which the setup error's snackbar sits
/// above.
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
            key: OnboardingOrientationPage.dividerKey,
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            OsdSpace.textInset,
            0,
            OsdSpace.textInset,
            OsdSpace.bottomGap(context, OnboardingOrientationPage.edgeGap),
          ),
          child: OnboardingRise(
            entrance: entrance,
            delay: OnboardingMotion.closingDelay,
            length: OnboardingMotion.tileIn,
            rise: 0,
            child: const SnackbarAnchor(
              gap: OsdSpace.snackbarAboveCta,
              child: _ContinueButton(),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A shape's tile: rebuilt only when the pick changes.
class _Tile extends StatelessWidget {
  const _Tile({required this.orientation});

  final VideoOrientation orientation;

  @override
  Widget build(BuildContext context) {
    final bool selected = context.select<OnboardingCubit, bool>(
      (OnboardingCubit cubit) => cubit.state.orientation == orientation,
    );
    final bool landscape = orientation == VideoOrientation.landscape;
    return OrientationOptionTile(
      key: OnboardingOrientationPage.tileKey(orientation),
      orientation: orientation,
      name: landscape ? Strings.landscape : Strings.portrait,
      detail: landscape
          ? Strings.orientationLandscapeDetail
          : Strings.orientationPortraitDetail,
      selected: selected,
      onTap: () => context.read<OnboardingCubit>().pickOrientation(orientation),
    );
  }
}

/// "Continue": off until a shape is picked, then fading on; a spinner
/// while the diary is being made (a "Try again" after a failure runs
/// here too).
class _ContinueButton extends StatelessWidget {
  const _ContinueButton();

  @override
  Widget build(BuildContext context) {
    final (bool picked, bool working) = context
        .select<OnboardingCubit, (bool, bool)>(
          (OnboardingCubit cubit) => (
            cubit.state.orientation != null,
            cubit.state.status == OnboardingStatus.finishing,
          ),
        );
    return FadeOnEnable(
      enabled: picked,
      child: PrimaryButton(
        key: OnboardingOrientationPage.continueKey,
        label: CommonLabels.of(context).continueAction,
        size: OsdButtonSize.large,
        loading: working,
        haptic: OsdHaptic.light,
        onPressed: picked
            ? () => unawaited(context.read<OnboardingCubit>().goToPermissions())
            : null,
      ),
    );
  }
}
