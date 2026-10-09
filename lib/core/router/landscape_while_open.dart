import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/platform/screen_orientation_gateway.dart';

/// Lets the phone turn the screen sideways while its page is open (the app
/// is portrait; the viewer and the movie player may turn).
///
/// Landscape is allowed from the moment the page is pushed; portrait comes
/// back as soon as the page starts to close (its route animation reverses),
/// so the page below never lays out sideways, and at the latest when the
/// page goes away. The routes file wraps the page in it.
class LandscapeWhileOpen extends StatefulWidget {
  const LandscapeWhileOpen({
    super.key,
    required this.orientation,
    required this.child,
  });

  final ScreenOrientationGateway orientation;
  final Widget child;

  @override
  State<LandscapeWhileOpen> createState() => _LandscapeWhileOpenState();
}

class _LandscapeWhileOpenState extends State<LandscapeWhileOpen> {
  Animation<double>? _route;

  /// What the gateway was told last: landscape allowed.
  bool _allowed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Animation<double>? route = ModalRoute.of(context)?.animation;
    if (identical(route, _route)) return;
    _route?.removeStatusListener(_routeChanged);
    _route = route?..addStatusListener(_routeChanged);
    _routeChanged(route?.status ?? AnimationStatus.completed);
  }

  @override
  void dispose() {
    _route?.removeStatusListener(_routeChanged);
    _allow(false);
    super.dispose();
  }

  void _routeChanged(AnimationStatus status) => _allow(switch (status) {
    AnimationStatus.forward || AnimationStatus.completed => true,
    AnimationStatus.reverse || AnimationStatus.dismissed => false,
  });

  void _allow(bool allowed) {
    if (allowed == _allowed) return;
    _allowed = allowed;
    unawaited(
      allowed
          ? widget.orientation.allowLandscape()
          : widget.orientation.portraitOnly(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
