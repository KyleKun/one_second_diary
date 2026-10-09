import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Swipe down to close the viewer.
///
/// A vertical drag anywhere on the viewer moves [builder]'s `drag` (how far
/// down, in px): the video follows the finger and shrinks, the black page
/// fades so the page it was opened from shows through, and the chrome
/// fades out ([chromeFade], [backgroundFade], [scaleAt]). Let go past
/// [closeDistance], or flicked down faster than [closeVelocity], it calls
/// [onDismiss] (the viewer closes, the video flying back from where it was
/// dropped); otherwise it springs back (`OsdMotion.dragDismissSpring`), at
/// once under reduced motion, where the video never shrinks either.
///
/// The viewer's route is opaque, so the page under it is not painted; while
/// dragged, the route's first overlay entry is made see-through, and made
/// opaque again once the viewer is back at rest.
class ViewerDismiss extends StatefulWidget {
  const ViewerDismiss({
    super.key,
    required this.onDismiss,
    required this.builder,
  });

  /// Past this, letting go closes the viewer (px).
  static const double closeDistance = 120;

  /// A flick down faster than this closes the viewer (px/s).
  static const double closeVelocity = 700;

  /// The chrome's opacity for a drag: gone by 40 px.
  static const Animatable<double> chromeFade = _FadeOver(40);

  /// The black page's opacity for a drag: .4 by 200 px.
  static const Animatable<double> backgroundFade = _FadeOver(200, floor: .4);

  static const double _shrinkOver = 300;
  static const double _smallest = .9;

  /// The video's scale for [drag]: .9 by 300 px; 1 under reduced motion.
  static double scaleAt(BuildContext context, double drag) =>
      OsdMotion.reduced(context)
      ? 1
      : 1 - (1 - _smallest) * (drag / _shrinkOver).clamp(0, 1);

  final VoidCallback onDismiss;

  /// The viewer, with how far it is dragged down (px).
  final Widget Function(BuildContext context, Animation<double> drag) builder;

  @override
  State<ViewerDismiss> createState() => _ViewerDismissState();
}

class _ViewerDismissState extends State<ViewerDismiss>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drag = AnimationController.unbounded(
    vsync: this,
  );
  ModalRoute<Object?>? _route;
  bool _dragging = false;
  bool _dismissed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  void _started(DragStartDetails _) {
    if (_dismissed) return;
    _dragging = true;
    _drag.stop();
    _showBelow(show: true);
  }

  void _moved(DragUpdateDetails details) {
    if (_dismissed) return;
    _drag.value = math.max(0, _drag.value + (details.primaryDelta ?? 0));
  }

  void _ended(DragEndDetails details) {
    if (_dismissed) return;
    _dragging = false;
    final double velocity = details.primaryVelocity ?? 0;
    if (_drag.value > ViewerDismiss.closeDistance ||
        velocity > ViewerDismiss.closeVelocity) {
      _dismissed = true;
      widget.onDismiss();
      return;
    }
    _springBack(velocity);
  }

  void _cancelled() {
    if (_dismissed) return;
    _dragging = false;
    _springBack(0);
  }

  void _springBack(double velocity) {
    if (_drag.value == 0 || OsdMotion.reduced(context)) {
      _atRest();
      return;
    }
    _drag
        .animateWith(
          SpringSimulation(
            OsdMotion.dragDismissSpring,
            _drag.value,
            0,
            velocity,
          ),
        )
        .whenCompleteOrCancel(() {
          if (mounted && !_dragging && !_dismissed) _atRest();
        });
  }

  void _atRest() {
    _drag.value = 0;
    _showBelow(show: false);
  }

  /// Lets the page under the viewer be painted (or not) while it rests on
  /// top; a route moving in or out already shows it.
  void _showBelow({required bool show}) {
    final ModalRoute<Object?>? route = _route;
    if (route == null ||
        !route.isCurrent ||
        route.overlayEntries.isEmpty ||
        route.animation?.status != AnimationStatus.completed) {
      return;
    }
    final OverlayEntry entry = route.overlayEntries.first;
    final bool opaque = !show && route.opaque;
    if (entry.opaque != opaque) entry.opaque = opaque;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    // Screen readers close the viewer with its button: a pretend scroll
    // would close it by surprise.
    excludeFromSemantics: true,
    behavior: HitTestBehavior.opaque,
    onVerticalDragStart: _started,
    onVerticalDragUpdate: _moved,
    onVerticalDragEnd: _ended,
    onVerticalDragCancel: _cancelled,
    child: widget.builder(context, _drag),
  );
}

/// 1 at rest, falling linearly to [floor] over the first [over] px of drag.
class _FadeOver extends Animatable<double> {
  const _FadeOver(this.over, {this.floor = 0});

  final double over;
  final double floor;

  @override
  double transform(double t) => 1 - (1 - floor) * (t / over).clamp(0, 1);
}
