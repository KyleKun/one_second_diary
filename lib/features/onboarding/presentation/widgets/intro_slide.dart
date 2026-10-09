import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/features/onboarding/presentation/onboarding_motion.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/illustration_card.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Builds a slide's artwork, animated by its [entrance] (0 → 1 over the
/// artwork's entrance length).
typedef IntroArtworkBuilder =
    Widget Function(BuildContext context, Animation<double> entrance);

/// One intro slide: the tinted illustration card over the title and the
/// body.
///
/// Layout: the card keeps its shape; on a shorter screen it shrinks first
/// (never below [minCardHeight]) so the text stays whole, and below that
/// the slide scrolls.
///
/// Motion: the first time the slide is [active] its artwork enters (over
/// [entranceLength]) and the text fades in, rising, shortly after. It runs
/// once: the carousel keeps a slide it has shown, so swiping back to it
/// shows it assembled. While the page is dragged, the artwork lags behind
/// its card and the text fades with the distance. None of it under reduced
/// motion.
class IntroSlide extends StatefulWidget {
  const IntroSlide({
    super.key,
    required this.index,
    required this.pages,
    required this.active,
    required this.tint,
    required this.title,
    required this.body,
    required this.entranceLength,
    required this.artwork,
  });

  static const Key titleKey = Key('introSlide.title');

  static const Key bodyKey = Key('introSlide.body');

  /// The card never gets shorter than this.
  static const double minCardHeight = 180;

  /// The space kept free under the text, above the footer.
  static const double bottomGap = 24;

  /// Between the card and the title.
  static const double textTop = 34;

  /// This slide's page.
  final int index;

  /// The carousel's controller: the page offset drives the drag effects.
  final PageController pages;

  /// Whether the carousel is on this slide; its entrance runs the first
  /// time it is.
  final bool active;

  final Color tint;

  final String title;
  final String body;

  /// How long the artwork's entrance takes.
  final Duration entranceLength;

  final IntroArtworkBuilder artwork;

  @override
  State<IntroSlide> createState() => _IntroSlideState();
}

class _IntroSlideState extends State<IntroSlide>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  /// Three slides: keeping them costs little, and a slide swiped back to
  /// never shows an empty card nor enters again.
  @override
  bool get wantKeepAlive => true;

  late final Duration _length = widget.entranceLength > _textEnd
      ? widget.entranceLength
      : _textEnd;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: _length,
  );

  static final Duration _textEnd =
      OnboardingMotion.textDelay + OnboardingMotion.textIn;

  late final CurvedAnimation _text = CurvedAnimation(
    parent: _entrance,
    curve: OnboardingMotion.span(
      OnboardingMotion.textDelay,
      OnboardingMotion.textIn,
      _length,
      curve: OnboardingMotion.textCurve,
    ),
  );

  late final CurvedAnimation _artwork = CurvedAnimation(
    parent: _entrance,
    curve: OnboardingMotion.span(Duration.zero, widget.entranceLength, _length),
  );

  bool _entered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enterIfActive();
  }

  @override
  void didUpdateWidget(IntroSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    _enterIfActive();
  }

  void _enterIfActive() {
    if (_entered || !widget.active) return;
    _entered = true;
    if (OsdMotion.reduced(context)) {
      _entrance.value = 1;
    } else {
      unawaited(_entrance.forward());
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _artwork.dispose();
    _entrance.dispose();
    super.dispose();
  }

  /// How far the page is from this slide, in pages.
  double get _drift {
    final PageController pages = widget.pages;
    if (!pages.hasClients || !pages.position.hasContentDimensions) return 0;
    return (pages.page ?? widget.index.toDouble()) - widget.index;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final bool reduced = OsdMotion.reduced(context);
    final Widget artwork = widget.artwork(context, _artwork);
    final Widget text = Padding(
      padding: const EdgeInsets.fromLTRB(
        OsdSpace.onboardingTextInset,
        IntroSlide.textTop,
        OsdSpace.onboardingTextInset,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: OsdSpace.s14,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              widget.title,
              key: IntroSlide.titleKey,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textScaler: OsdTextScale.scalerFor(
                context,
                OsdTextScaleRole.display,
              ),
              style: typography.displayOnboarding.copyWith(color: colors.tx),
            ),
          ),
          Text(
            widget.body,
            key: IntroSlide.bodyKey,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: typography.body17Loose.copyWith(color: colors.mu),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cardWidth = constraints.maxWidth - 2 * OsdSpace.textInset;
        final double cardHeight =
            cardWidth *
            IllustrationCard.artworkSize.height /
            IllustrationCard.artworkSize.width;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: OsdSpace.s6),
                  // Loose: the card takes what the text leaves, up to its
                  // own shape, and any space left goes under the text.
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: OsdSpace.textInset,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: IntroSlide.minCardHeight,
                          maxHeight: cardHeight,
                        ),
                        child: SizedBox.expand(
                          child: AnimatedBuilder(
                            animation: widget.pages,
                            builder: (BuildContext context, Widget? child) =>
                                IllustrationCard(
                                  tint: widget.tint,
                                  drift: reduced ? 0 : _drift,
                                  artwork: child!,
                                ),
                            child: artwork,
                          ),
                        ),
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: widget.pages,
                    builder: (BuildContext context, Widget? child) => Opacity(
                      opacity: reduced
                          ? 1
                          : (1 - OnboardingMotion.textFade * _drift.abs())
                                .clamp(0, 1),
                      child: child,
                    ),
                    child: AnimatedBuilder(
                      animation: _text,
                      builder: (BuildContext context, Widget? child) => Opacity(
                        opacity: _text.value,
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            OnboardingMotion.textRise * (1 - _text.value),
                          ),
                          child: child,
                        ),
                      ),
                      child: text,
                    ),
                  ),
                  const SizedBox(height: IntroSlide.bottomGap),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
