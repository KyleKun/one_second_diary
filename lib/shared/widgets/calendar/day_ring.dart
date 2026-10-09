import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';

/// The ring behind a calendar day: a [gap] of the surface, then a band of
/// [color] (CO for today, TX for the selected day), both following the
/// day's rounded corners (their radius grows with their distance from it).
/// It paints outside its box, so its parents must not clip.
///
/// A ring that appears scales up while fading in; one that goes fades out
/// in its last colour. Under reduced motion both are plain fades.
class DayRing extends StatefulWidget {
  const DayRing({super.key, required this.color, required this.gap});

  /// The ring (painted behind the day).
  static const Key ringKey = Key('dayRing.ring');

  /// The ring colour; null for no ring.
  final Color? color;

  /// The surface under the calendar, the gap between day and ring.
  final Color gap;

  @override
  State<DayRing> createState() => _DayRingState();
}

class _DayRingState extends State<DayRing> {
  static const Duration _in = Duration(milliseconds: 160);
  static const Duration _out = Duration(milliseconds: 120);
  static const double _fromScale = .9;
  late Color? _last = widget.color;

  @override
  void didUpdateWidget(DayRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.color != null) _last = widget.color;
  }

  @override
  Widget build(BuildContext context) {
    final bool visible = widget.color != null;
    final bool reduced = OsdMotion.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: visible ? 1 : 0),
      duration: OsdMotion.d(context, visible ? _in : _out),
      curve: OsdMotion.curve(
        context,
        visible ? Curves.easeOutCubic : OsdMotion.dialogOutCurve,
      ),
      builder: (BuildContext context, double t, _) {
        final Color? color = _last;
        if (color == null || (t == 0 && !visible)) {
          return const SizedBox.shrink();
        }
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: visible && !reduced ? lerpDouble(_fromScale, 1, t)! : 1,
            child: CustomPaint(
              key: DayRing.ringKey,
              painter: _RingPainter(ring: color, gap: widget.gap),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

/// The band of [ring] around the band of [gap], each a rounded rectangle
/// concentric with the day's (a box shadow's spread keeps the day's own
/// radius, which leaves the corners uneven).
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.ring, required this.gap});

  static const double _gapSpread = 2;

  /// Keep under half of `OsdSpace.gridGapCalendar`, or neighbouring rings meet.
  static const double _ringSpread = 4;

  final Color ring;
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect day = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(OsdRadius.r10),
    );
    canvas
      ..drawRRect(day.inflate(_ringSpread), Paint()..color = ring)
      ..drawRRect(day.inflate(_gapSpread), Paint()..color = gap);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.ring != ring || oldDelegate.gap != gap;
}
