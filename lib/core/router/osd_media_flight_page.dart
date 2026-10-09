import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// A page that a piece of media flies into: the camera from Today's record
/// button, the viewer from a clip, the movie player from a movie. The page
/// fades in over [fadeIn] while the shared-element `Hero` flies for
/// [duration]; it leaves over [reverseDuration], the hero flying back.
///
/// Heroes fly straight: the route's navigator has go_router's plain
/// `HeroController`. The page below stays still. The platform's transition
/// still wraps the page, held at rest, so the iOS edge swipe and Android
/// predictive back keep popping it. Under reduced motion it is the theme's
/// 150 ms crossfade (the hero is then a fade too: wrap heroes in
/// `HeroMode(enabled: !OsdMotion.reduced(context))`).
class OsdMediaFlightPage<T> extends Page<T> {
  const OsdMediaFlightPage({
    required this.child,
    required this.duration,
    required this.fadeIn,
    required this.reverseDuration,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  }) : assert(fadeIn <= duration, 'fadeIn is part of the flight');

  final Widget child;

  /// The flight in.
  final Duration duration;

  /// How long the page takes to fade in, from the start of the flight.
  final Duration fadeIn;

  /// The flight back.
  final Duration reverseDuration;

  @override
  Route<T> createRoute(BuildContext context) =>
      _MediaFlightPageRoute<T>(page: this);
}

class _MediaFlightPageRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  _MediaFlightPageRoute({required OsdMediaFlightPage<T> page})
    : super(settings: page);

  OsdMediaFlightPage<T> get _page => settings as OsdMediaFlightPage<T>;

  bool get _reduced => OsdMotion.reduced(navigator!.context);

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  bool get maintainState => true;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';

  @override
  Duration get transitionDuration =>
      _reduced ? super.transitionDuration : _page.duration;

  @override
  Duration get reverseTransitionDuration =>
      _reduced ? super.reverseTransitionDuration : _page.reverseDuration;

  // The page below stays still while the media flies.
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
    if (OsdMotion.reduced(context)) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return _MediaFade(
      animation: animation,
      end: _page.fadeIn.inMicroseconds / _page.duration.inMicroseconds,
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

/// The page fading in over the first [end] of the flight.
class _MediaFade extends StatefulWidget {
  const _MediaFade({
    required this.animation,
    required this.end,
    required this.child,
  });

  final Animation<double> animation;
  final double end;
  final Widget child;

  @override
  State<_MediaFade> createState() => _MediaFadeState();
}

class _MediaFadeState extends State<_MediaFade> {
  late CurvedAnimation _opacity = _curve();

  CurvedAnimation _curve() => CurvedAnimation(
    parent: widget.animation,
    curve: Interval(0, widget.end, curve: Curves.easeOutCubic),
  );

  @override
  void didUpdateWidget(_MediaFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation == widget.animation &&
        oldWidget.end == widget.end) {
      return;
    }
    _opacity.dispose();
    _opacity = _curve();
  }

  @override
  void dispose() {
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}
