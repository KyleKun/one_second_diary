import 'package:flutter/widgets.dart';
import 'package:one_second_diary/features/today/domain/today_carousel_geometry.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// How Today's pager settles when released: on the next page after a
/// fling, else on the nearest page, with the carousel spring
/// (`OsdMotion.carouselSpring`). The last page end-aligns
/// ([TodayCarouselGeometry]).
///
/// [geometry] is read at each release, so the pager's latest layout (a
/// page narrowing as the second clip arrives, a rotation) decides.
///
/// When the pages change size while it rests (the frame morphing to the
/// other profile shape, a resized window), it stays on the page in view:
/// [restingOffset] gives where that page now rests (null while the pager
/// is about to move on its own).
///
/// Under reduced motion ([reducedMotion]) it settles on a stiff, critically
/// damped spring: about 100 ms, with no overshoot.
class ClipSnapPhysics extends ScrollPhysics {
  const ClipSnapPhysics({
    required this.geometry,
    required this.restingOffset,
    this.reducedMotion = false,
    super.parent,
  });

  /// The pager's current layout.
  final ValueGetter<TodayCarouselGeometry> geometry;

  /// Where the page in view rests in the current layout.
  final ValueGetter<double?> restingOffset;

  final bool reducedMotion;

  static final SpringDescription _reducedSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 1600);

  @override
  ClipSnapPhysics applyTo(ScrollPhysics? ancestor) => ClipSnapPhysics(
    geometry: geometry,
    restingOffset: restingOffset,
    reducedMotion: reducedMotion,
    parent: buildParent(ancestor),
  );

  @override
  SpringDescription get spring =>
      reducedMotion ? _reducedSpring : OsdMotion.carouselSpring;

  @override
  bool get allowImplicitScrolling => false;

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final double? resting = isScrolling ? null : restingOffset();
    if (resting == null) {
      return super.adjustPositionForNewDimensions(
        oldPosition: oldPosition,
        newPosition: newPosition,
        isScrolling: isScrolling,
        velocity: velocity,
      );
    }
    return resting.clamp(
      newPosition.minScrollExtent,
      newPosition.maxScrollExtent,
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent) ||
        position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    final Tolerance tolerance = toleranceFor(position);
    final double target = geometry().snapTarget(
      position.pixels,
      velocity: velocity,
    );
    if ((target - position.pixels).abs() < tolerance.distance &&
        velocity.abs() < tolerance.velocity) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}
