import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Stroke, dash and gap of every dashed border.
abstract final class OsdDash {
  static const double stroke = 1.5;

  /// Nominal dash length.
  static const double dash = 6;

  /// Nominal gap length.
  static const double gap = 4;

  /// Where [count] dashes of a closed path [length] long start and end,
  /// measured from the path's start (the top centre).
  ///
  /// The dashes are spread evenly: the count is the even number that keeps the
  /// dash/gap ratio closest to nominal, and the first dash is centred on the
  /// start, so the pattern is mirror-symmetric in both axes and the corners
  /// match. A start below 0 wraps around the end of the path.
  static List<({double start, double end})> layout(
    double length, {
    double dash = OsdDash.dash,
    double gap = OsdDash.gap,
  }) {
    if (length <= 0) return const <({double start, double end})>[];
    final count = math.max(2, 2 * (length / (2 * (dash + gap))).round());
    final period = length / count;
    final dashLength = period * dash / (dash + gap);
    return <({double start, double end})>[
      for (var i = 0; i < count; i++)
        (start: i * period - dashLength / 2, end: i * period + dashLength / 2),
    ];
  }
}

Path _dashed(Path outline, double progress) {
  final metric = outline.computeMetrics().first;
  final dashes = OsdDash.layout(metric.length);
  final shown = (dashes.length * progress.clamp(0, 1)).round();
  final path = Path();
  for (final dash in dashes.take(shown)) {
    if (dash.start < 0) {
      path
        ..addPath(
          metric.extractPath(metric.length + dash.start, metric.length),
          Offset.zero,
        )
        ..addPath(metric.extractPath(0, dash.end), Offset.zero);
    } else {
      path.addPath(metric.extractPath(dash.start, dash.end), Offset.zero);
    }
  }
  return path;
}

Paint _stroke(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = OsdDash.stroke;

/// Paints a dashed rounded rectangle along the inside of its box: the path
/// runs on the rect deflated by half the stroke, so the stroke stays inside,
/// and starts at the top centre, clockwise.
class DashedRRectPainter extends CustomPainter {
  const DashedRRectPainter({
    required this.color,
    required this.borderRadius,
    this.progress = 1,
  });

  final Color color;

  /// The box's corner radius (the path uses it minus half the stroke).
  final BorderRadius borderRadius;

  /// The share of dashes drawn, clockwise from the top centre, for a draw-in.
  final double progress;

  /// The dashed outline for a box of [size].
  Path outline(Size size) {
    const inset = OsdDash.stroke / 2;
    final r = borderRadius.toRRect(Offset.zero & size).deflate(inset);
    return Path()
      ..moveTo(r.center.dx, r.top)
      ..lineTo(r.right - r.trRadiusX, r.top)
      ..arcToPoint(Offset(r.right, r.top + r.trRadiusY), radius: r.trRadius)
      ..lineTo(r.right, r.bottom - r.brRadiusY)
      ..arcToPoint(Offset(r.right - r.brRadiusX, r.bottom), radius: r.brRadius)
      ..lineTo(r.left + r.blRadiusX, r.bottom)
      ..arcToPoint(Offset(r.left, r.bottom - r.blRadiusY), radius: r.blRadius)
      ..lineTo(r.left, r.top + r.tlRadiusY)
      ..arcToPoint(Offset(r.left + r.tlRadiusX, r.top), radius: r.tlRadius)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawPath(_dashed(outline(size), progress), _stroke(color));
  }

  @override
  bool shouldRepaint(DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.progress != progress;
}

/// Paints a dashed circle inside its box.
class DashedCirclePainter extends CustomPainter {
  const DashedCirclePainter({required this.color, this.progress = 1});

  final Color color;

  /// The share of dashes drawn, clockwise from the top.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(OsdDash.stroke / 2);
    final outline = Path()
      ..arcTo(rect, -math.pi / 2, math.pi, true)
      ..arcTo(rect, math.pi / 2, math.pi, false)
      ..close();
    canvas.drawPath(_dashed(outline, progress), _stroke(color));
  }

  @override
  bool shouldRepaint(DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}

/// A dashed border behind [child], taking no layout space.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.color,
    this.borderRadius = BorderRadius.zero,
    this.shape = BoxShape.rectangle,
    this.progress = 1,
    this.child,
  });

  final Color color;

  /// The corner radius, for rectangles.
  final BorderRadius borderRadius;

  /// A rounded rectangle or a circle.
  final BoxShape shape;

  /// The share of dashes drawn (1 = all).
  final double progress;

  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: shape == BoxShape.circle
        ? DashedCirclePainter(color: color, progress: progress)
        : DashedRRectPainter(
            color: color,
            borderRadius: borderRadius,
            progress: progress,
          ),
    child: child,
  );
}
