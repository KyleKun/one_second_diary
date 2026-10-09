import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_colors.dart';

/// The ring around the recording shutter (forced dark): a track and a CO arc
/// from 12 o'clock, clockwise.
///
/// It repaints from [progress] (the recording clock) without rebuilding, and
/// it is linear because it is a clock: it keeps advancing under reduced
/// motion. Decorative: recording is announced by the page.
class RecordingProgressRing extends StatelessWidget {
  const RecordingProgressRing({
    super.key,
    required this.progress,
    this.size = 88,
  });

  /// Elapsed share of the clip, 0 to 1.
  final ValueListenable<double> progress;

  /// The box; the ring's outer edge touches it.
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _RingPainter(progress)),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress) : super(repaint: progress);

  static const double _stroke = 5;

  final ValueListenable<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - _stroke / 2;
    canvas
      ..drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..color = OsdColors.dark.off,
      )
      ..drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.value.clamp(0, 1),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.butt
          ..color = OsdColors.dark.co,
      );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
