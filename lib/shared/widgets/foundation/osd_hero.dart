import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// A shared-element flight: [child], clipped to [radius], flies to the
/// `OsdHero` with the same [tag] on the next route (tags from `HeroTags`).
///
/// The corners morph from one radius to the other, and back when the route
/// pops. The flight is straight and takes the route's duration. Under
/// reduced motion nothing flies: the route's crossfade shows the page.
/// Without a target the page's own transition is all there is.
class OsdHero extends StatelessWidget {
  const OsdHero({
    super.key,
    required this.tag,
    required this.radius,
    required this.child,
  });

  /// The flying copy, while it flies.
  static const Key shuttleKey = Key('osdHero.shuttle');

  final Object tag;

  /// The corner radius here.
  final double radius;

  final Widget child;

  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final ClipRRect from = (fromHeroContext.widget as Hero).child as ClipRRect;
    final ClipRRect to = (toHeroContext.widget as Hero).child as ClipRRect;
    // The animation runs 0 → 1 on a push and 1 → 0 on a pop, where the
    // "from" hero is on the route leaving.
    final (
      BorderRadiusGeometry at0,
      BorderRadiusGeometry at1,
    ) = switch (direction) {
      HeroFlightDirection.push => (from.borderRadius, to.borderRadius),
      HeroFlightDirection.pop => (to.borderRadius, from.borderRadius),
    };
    return AnimatedBuilder(
      key: shuttleKey,
      animation: animation,
      builder: (BuildContext context, Widget? child) => ClipRRect(
        borderRadius:
            BorderRadiusGeometry.lerp(at0, at1, animation.value) ??
            BorderRadius.zero,
        child: child,
      ),
      child: to.child,
    );
  }

  @override
  Widget build(BuildContext context) => HeroMode(
    enabled: !OsdMotion.reduced(context),
    child: Hero(
      tag: tag,
      flightShuttleBuilder: _shuttle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    ),
  );
}
