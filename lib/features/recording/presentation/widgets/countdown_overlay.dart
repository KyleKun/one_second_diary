import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/features/recording/presentation/camera_motion.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/upright_rotation.dart';
import 'package:one_second_diary/theme/osd_camera.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The countdown over the preview: [numeral], centred and turned upright with
/// the phone. Each number scales down with a fade and leaves before its second
/// is over; under reduced motion it only fades. It is a live region that says
/// [semanticsLabel]. Nothing shows without a [count].
class CountdownOverlay extends StatelessWidget {
  const CountdownOverlay({
    super.key,
    required this.count,
    required this.numeral,
    required this.semanticsLabel,
    required this.orientation,
  });

  /// The number shown (3, 2, 1), or null.
  final int? count;

  /// [count] in the language's digits.
  final String numeral;

  final String semanticsLabel;

  final DeviceOrientation orientation;

  static const Shadow _shadow = Shadow(
    color: Color(0x66000000),
    blurRadius: 24,
  );

  @override
  Widget build(BuildContext context) {
    final int? count = this.count;
    if (count == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Center(
          child: UprightRotation(
            orientation: orientation,
            child: _Numeral(
              key: ValueKey<int>(count),
              text: numeral,
              style: context.typography.displayCountdown.copyWith(
                color: OsdCamera.white,
                shadows: const <Shadow>[_shadow],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One number of the countdown, from the moment it comes in to the moment
/// it has left.
class _Numeral extends StatefulWidget {
  const _Numeral({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_Numeral> createState() => _NumeralState();
}

class _NumeralState extends State<_Numeral>
    with SingleTickerProviderStateMixin {
  static const double _enterScale = 1.25;
  static const double _exitScale = .9;

  /// From coming in to having left: a second, the countdown's step.
  static final Duration _life =
      CameraMotion.countdownExitAt + OsdMotion.selection;

  // A number stays its second under reduced motion too (the platform
  // setting would run an ordinary controller at 5 %); only its fades are
  // shortened.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _life,
    animationBehavior: AnimationBehavior.preserve,
  );
  late Animation<double> _opacity;
  late Animation<double> _scale;
  bool? _reduced;

  @override
  void initState() {
    super.initState();
    _clock.forward().ignore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduced = OsdMotion.reduced(context);
    if (reduced == _reduced) return;
    _reduced = reduced;
    final Duration enter = OsdMotion.d(context, OsdMotion.standard);
    final Duration exit = OsdMotion.d(context, OsdMotion.selection);
    final double enterEnd = _fraction(enter);
    final double exitStart = _fraction(
      reduced ? _life - exit : CameraMotion.countdownExitAt,
    );
    // The fades ease as the scale does (a linear crossfade under reduced
    // motion).
    final Curve enterCurve = OsdMotion.curve(context, Curves.easeOutCubic);
    final Curve exitCurve = OsdMotion.curve(context, Curves.easeIn);
    _opacity = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: enterCurve)),
        weight: enterEnd,
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(1),
        weight: exitStart - enterEnd,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: exitCurve)),
        weight: 1 - exitStart,
      ),
    ]).animate(_clock);
    _scale = reduced
        ? const AlwaysStoppedAnimation<double>(1)
        : TweenSequence<double>(<TweenSequenceItem<double>>[
            TweenSequenceItem<double>(
              tween: Tween<double>(
                begin: _enterScale,
                end: 1,
              ).chain(CurveTween(curve: enterCurve)),
              weight: enterEnd,
            ),
            TweenSequenceItem<double>(
              tween: ConstantTween<double>(1),
              weight: exitStart - enterEnd,
            ),
            TweenSequenceItem<double>(
              tween: Tween<double>(
                begin: 1,
                end: _exitScale,
              ).chain(CurveTween(curve: exitCurve)),
              weight: 1 - exitStart,
            ),
          ]).animate(_clock);
  }

  static double _fraction(Duration part) =>
      part.inMicroseconds / _life.inMicroseconds;

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: ScaleTransition(
      scale: _scale,
      // A big number: its growth with large text is capped.
      child: Text(
        widget.text,
        style: widget.style,
        textScaler: OsdTextScale.scalerFor(context, OsdTextScaleRole.display),
      ),
    ),
  );
}
