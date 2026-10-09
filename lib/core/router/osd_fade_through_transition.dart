import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The fade-through of a route replacement, driven by the route's
/// [animation] over `OsdMotion.fadeThrough`:
/// - out, the first `OsdMotion.fadeThroughOut`: the new page's background
///   fades in over the old page;
/// - in, the last `OsdMotion.fadeThroughIn`: the new page fades in, growing
///   from `OsdMotion.fadeThroughScale` to 1.
///
/// Only opacity and a transform animate, never layout.
class OsdFadeThroughTransition extends StatefulWidget {
  const OsdFadeThroughTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  /// The background fill between the two pages (tests read its opacity).
  static const Key fillKey = Key('osdFadeThrough.fill');

  final Animation<double> animation;
  final Widget child;

  @override
  State<OsdFadeThroughTransition> createState() =>
      _OsdFadeThroughTransitionState();
}

class _OsdFadeThroughTransitionState extends State<OsdFadeThroughTransition> {
  static final double _split =
      OsdMotion.fadeThroughOut.inMicroseconds /
      OsdMotion.fadeThrough.inMicroseconds;

  late CurvedAnimation _out;
  late CurvedAnimation _in;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _curve();
  }

  @override
  void didUpdateWidget(OsdFadeThroughTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation == widget.animation) return;
    _out.dispose();
    _in.dispose();
    _curve();
  }

  void _curve() {
    _out = CurvedAnimation(
      parent: widget.animation,
      curve: Interval(0, _split, curve: OsdMotion.fadeThroughCurve),
    );
    _in = CurvedAnimation(
      parent: widget.animation,
      curve: Interval(_split, 1, curve: OsdMotion.fadeThroughCurve),
    );
    _scale = Tween<double>(
      begin: OsdMotion.fadeThroughScale,
      end: 1,
    ).animate(_in);
  }

  @override
  void dispose() {
    _out.dispose();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        FadeTransition(
          opacity: _out,
          child: ColoredBox(
            key: OsdFadeThroughTransition.fillKey,
            color: context.colors.bg,
          ),
        ),
        FadeTransition(
          opacity: _in,
          child: ScaleTransition(scale: _scale, child: widget.child),
        ),
      ],
    );
  }
}
