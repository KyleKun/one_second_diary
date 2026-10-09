import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_loading_delay.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// How a skeleton block moves.
enum OsdSkeletonEffect {
  /// A SEL band sweeping across.
  shimmer,

  /// Opacity breathing.
  pulse,
}

/// A C2 placeholder block shaped like the content it stands for.
///
/// It appears after a short delay and moves with its [effect]. Under reduced
/// motion it is a static C2 block.
class OsdSkeletonBlock extends StatelessWidget {
  const OsdSkeletonBlock({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
    this.effect = OsdSkeletonEffect.shimmer,
  });

  /// A text bar.
  const OsdSkeletonBlock.text({
    super.key,
    this.width = 100,
    this.height = 14,
    this.effect = OsdSkeletonEffect.shimmer,
  }) : radius = 4;

  /// A thumbnail.
  const OsdSkeletonBlock.thumbnail({
    super.key,
    required this.width,
    required this.height,
    this.effect = OsdSkeletonEffect.shimmer,
  }) : radius = 14;

  /// The C2 block, once it is shown.
  static const Key blockKey = Key('osdSkeletonBlock.block');

  final double width;

  final double height;

  final double radius;

  final OsdSkeletonEffect effect;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: OsdLoadingDelay(
      loading: true,
      builder: (context, show) => show
          ? switch (effect) {
              OsdSkeletonEffect.shimmer => _Shimmer(
                key: blockKey,
                radius: BorderRadius.circular(radius),
              ),
              OsdSkeletonEffect.pulse => _Pulse(
                key: blockKey,
                radius: BorderRadius.circular(radius),
              ),
            }
          : const SizedBox.shrink(),
    ),
  );
}

class _Pulse extends StatefulWidget {
  const _Pulse({super.key, required this.radius});

  final BorderRadius radius;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: OsdMotion.pulse,
    value: 1,
  );

  late final Animation<double> _opacity = Tween<double>(
    begin: .55,
    end: 1,
  ).chain(CurveTween(curve: Curves.easeInOut)).animate(_controller);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (OsdMotion.loopsEnabled(context)) {
      if (!_controller.isAnimating) {
        unawaited(_controller.repeat(reverse: true));
      }
    } else {
      _controller
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.c2,
        borderRadius: widget.radius,
      ),
      child: const SizedBox.expand(),
    ),
  );
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({super.key, required this.radius});

  final BorderRadius radius;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: OsdMotion.shimmer,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (OsdMotion.loopsEnabled(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CustomPaint(
      painter: _ShimmerPainter(
        progress: _controller,
        base: colors.c2,
        band: OsdMotion.loopsEnabled(context) ? colors.sel : null,
        radius: widget.radius,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({
    required this.progress,
    required this.base,
    required this.band,
    required this.radius,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color base;
  final Color? band;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Offset.zero & size);
    canvas.drawRRect(rrect, Paint()..color = base);
    final band = this.band;
    if (band == null) return;
    final x = (progress.value * 2 - .5) * size.width;
    canvas
      ..save()
      ..clipRRect(rrect)
      ..drawRect(
        Rect.fromLTWH(x - size.width / 4, 0, size.width / 2, size.height),
        Paint()
          ..shader =
              LinearGradient(
                colors: <Color>[
                  band.withValues(alpha: 0),
                  band,
                  band.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromLTWH(
                  x - size.width / 4,
                  0,
                  size.width / 2,
                  size.height,
                ),
              ),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) =>
      oldDelegate.base != base ||
      oldDelegate.band != band ||
      oldDelegate.radius != radius;
}
