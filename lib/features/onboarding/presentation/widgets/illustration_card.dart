import 'package:flutter/material.dart';
import 'package:one_second_diary/features/onboarding/presentation/onboarding_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';

/// The tinted card that holds an intro slide's artwork: the page's tint
/// painted translucent over the background, clipping an artwork drawn in
/// [artworkSize] and scaled to fit, centred.
///
/// The artwork is part of the picture, not the text: it never follows the
/// text size, and its positions never mirror. While the page is
/// dragged ([drift] pages away from rest) it lags behind the card
/// ([OnboardingMotion.parallax]), so the frame outruns its contents.
class IllustrationCard extends StatelessWidget {
  const IllustrationCard({
    super.key,
    required this.tint,
    required this.artwork,
    this.drift = 0,
  });

  /// The box the artwork is drawn in.
  static const Size artworkSize = Size(350, 370);

  static const Key surfaceKey = Key('illustrationCard.surface');

  /// The card's tint (an `OsdTints` colour).
  final Color tint;

  /// The artwork, laid out in [artworkSize].
  final Widget artwork;

  /// How far the page is from rest, in pages (the page offset minus this
  /// slide's index).
  final double drift;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(OsdRadius.r32);
    final double direction = Directionality.of(context) == TextDirection.rtl
        ? -1
        : 1;
    return DecoratedBox(
      key: surfaceKey,
      decoration: BoxDecoration(color: tint, borderRadius: radius),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: <Widget>[
            // Positioned, so the card's intrinsic height is its own: the
            // slide shrinks it to fit the page.
            Positioned.fill(
              child: FractionalTranslation(
                translation: Offset(
                  drift * OnboardingMotion.parallax * direction,
                  0,
                ),
                // Its own layer: the drag only moves it, and its blurred
                // shadows are not painted again.
                child: RepaintBoundary(
                  child: FittedBox(
                    child: SizedBox.fromSize(
                      size: artworkSize,
                      child: MediaQuery.withNoTextScaling(
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: artwork,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
