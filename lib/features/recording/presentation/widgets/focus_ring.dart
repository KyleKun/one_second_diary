import 'package:flutter/widgets.dart';
import 'package:one_second_diary/features/recording/presentation/camera_motion.dart';
import 'package:one_second_diary/theme/osd_camera.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Where a tap focused the camera: a ring that lands, holds for
/// `CameraMotion.focusHold` and fades out. Under reduced motion it only
/// fades. Build a new one (a new key) for each tap; decoration only.
class FocusRing extends StatefulWidget {
  const FocusRing({super.key});

  static const Key ringKey = Key('focusRing.ring');

  /// Its diameter.
  static const double size = 72;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing>
    with SingleTickerProviderStateMixin {
  static const double _edge = 1.5;
  static const double _landFrom = 1.2;

  // The ring holds as long under reduced motion too (the platform setting
  // would run an ordinary controller at 5 %).
  late final AnimationController _clock = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  late Animation<double> _scale;
  late Animation<double> _opacity;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final bool reduced = OsdMotion.reduced(context);
    final Duration land = reduced ? Duration.zero : OsdMotion.badgeIn;
    final Duration fade = OsdMotion.d(context, CameraMotion.focusFade);
    final Duration life = land + CameraMotion.focusHold + fade;
    final double landEnd = land.inMicroseconds / life.inMicroseconds;
    final double fadeStart = 1 - fade.inMicroseconds / life.inMicroseconds;
    _clock.duration = life;
    _scale = reduced
        ? const AlwaysStoppedAnimation<double>(1)
        : Tween<double>(begin: _landFrom, end: 1)
              .chain(
                CurveTween(
                  curve: Interval(0, landEnd, curve: OsdMotion.badgeInCurve),
                ),
              )
              .animate(_clock);
    _opacity = Tween<double>(begin: 1, end: 0)
        .chain(
          CurveTween(curve: Interval(fadeStart, 1, curve: OsdMotion.fastCurve)),
        )
        .animate(_clock);
    _clock.forward().ignore();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          child: const SizedBox.square(
            key: FocusRing.ringKey,
            dimension: FocusRing.size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: OsdCamera.white, width: _edge),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
