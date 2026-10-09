import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/onboarding_motion.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/gallery_access_dialog_listener.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/intro_slide.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/memories_artwork.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/movie_artwork.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/privacy_artwork.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_round_next_button.dart';
import 'package:one_second_diary/shared/widgets/progress/page_dots.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_tints.dart';

/// The intro carousel: three slides that swipe over a fixed footer (the
/// page dots and Next). It can't be skipped.
///
/// Next on the last slide leaves the intro: the flow then shows the
/// orientation step, or the permissions step at once when the Default
/// profile's canvas is already decided (a reinstall).
class OnboardingIntroPage extends StatefulWidget {
  const OnboardingIntroPage({super.key});

  static const Key nextKey = Key('onboardingIntro.next');

  static const Key slidesKey = Key('onboardingIntro.slides');

  static const Key dotsKey = Key('onboardingIntro.dots');

  static const int slideCount = 3;

  /// The widest the page's column gets, centred on tablets.
  static const double maxWidth = 480;

  /// The room above the slides, kept as the design laid them out.
  static const double topGap = 46;

  /// The gap under the footer (`OsdSpace.bottomGap`'s base).
  static const double footerGap = 34;

  @override
  State<OnboardingIntroPage> createState() => _OnboardingIntroPageState();
}

class _OnboardingIntroPageState extends State<OnboardingIntroPage> {
  final PageController _pages = PageController();

  /// The slide the carousel is on.
  int _slide = 0;

  /// The slide the carousel rests on; null while it moves.
  int? _settled = 0;

  /// The slide the carousel last came to rest on.
  int _rested = 0;

  /// Where a running Next animation goes: a tap during it goes one
  /// further (taps retarget, they never queue).
  int? _target;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Next on the last slide: the orientation step, or the permissions step
  /// when the canvas is already decided.
  void _leave() => unawaited(context.read<OnboardingCubit>().leaveIntro());

  void _next() {
    final int target = (_target ?? _slide) + 1;
    if (target >= OnboardingIntroPage.slideCount) return _leave();
    _turnTo(target);
  }

  /// System back on the second and third slides.
  void _previous() {
    final int target = (_target ?? _slide) - 1;
    if (target >= 0) _turnTo(target);
  }

  void _turnTo(int target) {
    _target = target;
    if (OsdMotion.reduced(context)) {
      _pages.jumpToPage(target);
      _target = null;
      return;
    }
    unawaited(
      _pages
          .animateToPage(
            target,
            duration: OnboardingMotion.pageTurn,
            curve: OnboardingMotion.pageTurnCurve,
          )
          .whenComplete(() {
            if (_target == target) _target = null;
          }),
    );
  }

  /// Follows where the carousel rests, for the second slide's film, and
  /// ticks when it comes to rest on another slide.
  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification && _settled != null) {
      setState(() => _settled = null);
    } else if (notification is ScrollEndNotification) {
      final int rest = _position.round();
      if (rest != _settled) {
        if (_settled == null && rest != _rested) {
          unawaited(OsdHaptic.selection.play());
        }
        setState(() => _settled = _rested = rest);
      }
    }
    return false;
  }

  double get _position {
    if (!_pages.hasClients || !_pages.position.hasContentDimensions) {
      return _slide.toDouble();
    }
    return _pages.page ?? _slide.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final LocalDay today = context.select<OnboardingCubit, LocalDay>(
      (OnboardingCubit cubit) => cubit.state.today,
    );
    // The gallery refused as the diary is made from above the intro (the
    // reinstall path, once the permissions page is gone): explained here.
    return GalleryAccessDialogListener(
      child: PopScope<Object?>(
        canPop: _slide == 0,
        onPopInvokedWithResult: (bool didPop, _) {
          if (!didPop) _previous();
        },
        child: Scaffold(
          backgroundColor: colors.bg,
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: OnboardingIntroPage.maxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: OnboardingIntroPage.topGap),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _onScroll,
                        child: PageView.builder(
                          key: OnboardingIntroPage.slidesKey,
                          controller: _pages,
                          itemCount: OnboardingIntroPage.slideCount,
                          onPageChanged: (int slide) =>
                              setState(() => _slide = slide),
                          itemBuilder: (BuildContext context, int index) =>
                              IntroSlide(
                                index: index,
                                pages: _pages,
                                active: index == _slide,
                                tint: switch (index) {
                                  0 => OsdTints.coTint12,
                                  1 => OsdTints.purpleTint16,
                                  _ => OsdTints.greenTint14,
                                },
                                title: switch (index) {
                                  0 => Strings.introTitle1,
                                  1 => Strings.introTitle2,
                                  _ => Strings.onboardingIntro3Title,
                                },
                                body: switch (index) {
                                  0 => Strings.introDesc1,
                                  1 => Strings.introDesc2,
                                  _ => Strings.onboardingIntro3Body,
                                },
                                entranceLength: switch (index) {
                                  0 => MemoriesArtwork.entranceLength,
                                  1 => MovieArtwork.entranceLength,
                                  _ => PrivacyArtwork.entranceLength,
                                },
                                artwork:
                                    (
                                      BuildContext context,
                                      Animation<double> entrance,
                                    ) => switch (index) {
                                      0 => MemoriesArtwork(
                                        entrance: entrance,
                                        today: today,
                                      ),
                                      1 => MovieArtwork(
                                        entrance: entrance,
                                        running: _settled == 1,
                                        textDirection: Directionality.of(
                                          context,
                                        ),
                                      ),
                                      _ => PrivacyArtwork(
                                        entrance: entrance,
                                        textDirection: Directionality.of(
                                          context,
                                        ),
                                      ),
                                    },
                              ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        OsdSpace.textInset,
                        0,
                        OsdSpace.textInset,
                        OsdSpace.bottomGap(
                          context,
                          OnboardingIntroPage.footerGap,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          AnimatedBuilder(
                            animation: _pages,
                            builder: (BuildContext context, _) => PageDots(
                              key: OnboardingIntroPage.dotsKey,
                              count: OnboardingIntroPage.slideCount,
                              position: _position,
                              style: PageDotsStyle.brand,
                              semanticsLabel: Strings.onboardingPageIndicator(
                                current: _slide + 1,
                                total: OnboardingIntroPage.slideCount,
                              ),
                            ),
                          ),
                          OsdRoundNextButton(
                            key: OnboardingIntroPage.nextKey,
                            tooltip: Strings.onboardingNext,
                            onPressed: _next,
                          ),
                        ],
                      ),
                    ),
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
