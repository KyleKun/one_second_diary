import 'package:flutter/material.dart';
import 'package:one_second_diary/core/router/osd_fade_through_transition.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// A page that enters with the fade-through ([OsdFadeThroughTransition])
/// instead of the platform push: for route replacements, where the new page
/// takes the old one's place (the camera → the clip editor, the Create
/// movie steps, onboarding → Today).
///
/// The platform's transition still wraps the page, held at rest, so the iOS
/// edge swipe and Android predictive back keep popping it, and a page
/// pushed above it moves this one as usual. Under reduced motion it is the
/// theme's 150 ms crossfade, like every push.
///
/// With [fadeThrough] false it is a plain platform push: for a flow some
/// open with a push and one with a replacement (Create movie). The choice is
/// fixed when the route is made, and the page type is the same either way,
/// so a rebuild of the flow's page never replaces its route.
class OsdFadeThroughPage<T> extends Page<T> {
  const OsdFadeThroughPage({
    required this.child,
    this.fadeThrough = true,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;

  /// Whether the page enters with the fade-through; the platform push
  /// otherwise.
  final bool fadeThrough;

  @override
  Route<T> createRoute(BuildContext context) =>
      _FadeThroughPageRoute<T>(page: this);
}

class _FadeThroughPageRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  _FadeThroughPageRoute({required OsdFadeThroughPage<T> page})
    : _fadeThrough = page.fadeThrough,
      super(settings: page);

  OsdFadeThroughPage<T> get _page => settings as OsdFadeThroughPage<T>;

  /// The page's [OsdFadeThroughPage.fadeThrough] when the route was made.
  final bool _fadeThrough;

  /// The platform's transition: a plain push, or reduced motion.
  bool get _reduced => !_fadeThrough || OsdMotion.reduced(navigator!.context);

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  bool get maintainState => true;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';

  @override
  Duration get transitionDuration =>
      _reduced ? super.transitionDuration : OsdMotion.fadeThrough;

  @override
  Duration get reverseTransitionDuration =>
      _reduced ? super.reverseTransitionDuration : OsdMotion.fadeThrough;

  // The old page stays still under the fill (no iOS parallax).
  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _reduced ? super.delegatedTransition : null;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!_fadeThrough || OsdMotion.reduced(context)) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return OsdFadeThroughTransition(
      animation: animation,
      child: Theme.of(context).pageTransitionsTheme.buildTransitions<T>(
        this,
        context,
        kAlwaysCompleteAnimation,
        secondaryAnimation,
        child,
      ),
    );
  }
}
