import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Swipe sideways to step: a horizontal drag anywhere on the viewer goes to
/// the next clip (a swipe toward the start, the way a page turns) or the
/// previous one, through a day's clips first, then the neighbouring days
/// (the cubit's order, [onNext] and [onPrevious]).
///
/// - Let go past [stepDistance], or flicked faster than [stepVelocity], it
///   steps; the video leans the way it will go while dragged ([builder]'s
///   `shift`, in px), then settles over [stepDuration] as the new clip
///   slides in. Short of that it springs back
///   (`OsdMotion.dragDismissSpring`).
/// - At an end (no [onNext] or [onPrevious]) the video gives a little and
///   springs back: a rubber band, never a step.
/// - Under reduced motion the video never leans; a swipe past the
///   threshold still steps (the new clip cuts in).
/// - Its own recogniser, beside `ViewerDismiss`'s vertical one: the arena
///   gives the touch to whichever axis crosses the slop first, so a drag
///   down still closes the viewer, and the player's taps still play and
///   pause. In RTL the meaning flips with the layout: next waits at the
///   end, whichever side that is.
class ViewerSwipe extends StatefulWidget {
  const ViewerSwipe({
    super.key,
    required this.onPrevious,
    required this.onNext,
    required this.builder,
  });

  /// Past this, letting go steps (px): the viewfinder's swipe distance.
  static const double stepDistance = 64;

  /// A flick faster than this steps (px/s): the Today carousel's fling.
  static const double stepVelocity = 300;

  /// The step, between `OsdMotion.standard` and `emphasized`: the new clip
  /// slides in, and the lean settles.
  static const Duration stepDuration = Duration(milliseconds: 260);

  /// How much of the finger's travel the video follows toward a clip that
  /// is there, and at an end (the rubber band), and the most it moves.
  static const double _follow = .35;
  static const double _resist = .12;
  static const double _followMax = 72;

  /// Steps back, or null at the first clip.
  final VoidCallback? onPrevious;

  /// Steps on, or null at the last clip.
  final VoidCallback? onNext;

  /// The viewer, with how far the video leans sideways (px, signed in
  /// screen direction).
  final Widget Function(BuildContext context, Animation<double> shift) builder;

  @override
  State<ViewerSwipe> createState() => _ViewerSwipeState();
}

class _ViewerSwipeState extends State<ViewerSwipe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shift = AnimationController.unbounded(
    vsync: this,
  );

  /// How far the finger went since it touched down (px, screen direction).
  double _dragged = 0;

  @override
  void dispose() {
    _shift.dispose();
    super.dispose();
  }

  /// Whether a swipe of [dx] px (screen direction) goes toward the next
  /// clip: toward the start, where a page turns from.
  bool _isToNext(double dx) =>
      Directionality.of(context) == TextDirection.rtl ? dx > 0 : dx < 0;

  VoidCallback? _stepFor(double dx) =>
      _isToNext(dx) ? widget.onNext : widget.onPrevious;

  void _started(DragStartDetails _) {
    _dragged = 0;
    _shift.stop();
  }

  void _moved(DragUpdateDetails details) {
    _dragged += details.primaryDelta ?? 0;
    if (OsdMotion.reduced(context)) return;
    final double follow = _stepFor(_dragged) == null
        ? ViewerSwipe._resist
        : ViewerSwipe._follow;
    _shift.value = (_dragged * follow).clamp(
      -ViewerSwipe._followMax,
      ViewerSwipe._followMax,
    );
  }

  void _ended(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    // A flick decides the way; else where the finger went.
    final double drive = velocity.abs() > ViewerSwipe.stepVelocity
        ? velocity
        : _dragged.abs() > ViewerSwipe.stepDistance
        ? _dragged
        : 0;
    final VoidCallback? step = drive == 0 ? null : _stepFor(drive);
    if (step == null) {
      _springBack(velocity);
      return;
    }
    step();
    _settle();
  }

  void _cancelled() => _springBack(0);

  /// The lean settles as the new clip slides in, with it.
  void _settle() {
    if (_shift.value == 0) return;
    unawaited(
      _shift.animateTo(
        0,
        duration: OsdMotion.d(context, ViewerSwipe.stepDuration),
        curve: OsdMotion.curve(context, OsdMotion.standardCurve),
      ),
    );
  }

  void _springBack(double velocity) {
    if (_shift.value == 0) return;
    if (OsdMotion.reduced(context)) {
      _shift.value = 0;
      return;
    }
    unawaited(
      _shift.animateWith(
        SpringSimulation(
          OsdMotion.dragDismissSpring,
          _shift.value,
          0,
          velocity * ViewerSwipe._follow,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    // Screen readers step with the chevrons: a pretend scroll would move on
    // by surprise.
    excludeFromSemantics: true,
    behavior: HitTestBehavior.opaque,
    onHorizontalDragStart: _started,
    onHorizontalDragUpdate: _moved,
    onHorizontalDragEnd: _ended,
    onHorizontalDragCancel: _cancelled,
    child: widget.builder(context, _shift),
  );
}
