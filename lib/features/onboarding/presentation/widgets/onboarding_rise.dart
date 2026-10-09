import 'package:flutter/widgets.dart';
import 'package:one_second_diary/features/onboarding/presentation/onboarding_motion.dart';
import 'package:one_second_diary/shared/widgets/foundation/fade_rise.dart';

/// Fades [child] in while it rises [rise] px, over [length] from [delay]
/// into a page's [entrance]: the orientation and permissions pages build
/// up top to bottom with it on first display.
class OnboardingRise extends StatelessWidget {
  const OnboardingRise({
    super.key,
    required this.entrance,
    required this.delay,
    required this.length,
    required this.rise,
    required this.child,
  });

  /// How long the whole entrance takes.
  static const Duration total = Duration(milliseconds: 600);

  final Animation<double> entrance;
  final Duration delay;
  final Duration length;
  final double rise;
  final Widget child;

  @override
  Widget build(BuildContext context) => FadeRise(
    // A CurveTween keeps no listener of its own on the entrance.
    animation: entrance.drive(
      CurveTween(
        curve: OnboardingMotion.span(
          delay,
          length,
          total,
          curve: OnboardingMotion.textCurve,
        ),
      ),
    ),
    rise: rise,
    child: child,
  );
}
