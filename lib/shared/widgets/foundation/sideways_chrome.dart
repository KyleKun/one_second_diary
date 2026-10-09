import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';

/// What [SidewaysChrome] tells its builder.
///
/// - [sideways]: a phone turned sideways (not a tablet): lay the media out
///   full screen, the chrome over it.
/// - [shown]: how much the chrome shows (1, or 0 once hidden).
/// - [reveal]: brings the hidden chrome back; null while it shows. Cover
///   the media with a tap target that calls it, so the first tap only
///   brings the chrome back.
/// - [hide]: hides the chrome at once; null while it is hidden or always
///   shows. Put a tap target that calls it under the media and the chrome.
typedef SidewaysChromeState = ({
  bool sideways,
  Animation<double> shown,
  VoidCallback? reveal,
  VoidCallback? hide,
});

/// The chrome of a full-screen media page (the viewer, the movie player) on
/// a phone turned sideways: it lies over the media on [scrim] gradients and
/// hides [linger] after the last touch or on a tap beside the media; a tap
/// brings it back. Upright, on a
/// tablet, or with a screen reader on, it always shows. It fades over
/// `OsdMotion.fast` (at once under reduced motion).
class SidewaysChrome extends StatefulWidget {
  const SidewaysChrome({super.key, required this.builder});

  /// How long the chrome stays after a touch.
  static const Duration linger = Duration(milliseconds: 2500);

  /// The gradient under the chrome, from translucent black at the screen's
  /// edge ([top] or bottom) to clear.
  static BoxDecoration scrim({required bool top}) => BoxDecoration(
    gradient: LinearGradient(
      begin: top ? Alignment.topCenter : Alignment.bottomCenter,
      end: top ? Alignment.bottomCenter : Alignment.topCenter,
      colors: const <Color>[Color(0x66000000), Color(0x00000000)],
    ),
  );

  /// Builds the page for the current [SidewaysChromeState].
  final Widget Function(BuildContext context, SidewaysChromeState chrome)
  builder;

  @override
  State<SidewaysChrome> createState() => _SidewaysChromeState();
}

class _SidewaysChromeState extends State<SidewaysChrome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shown = AnimationController(
    vsync: this,
    duration: OsdMotion.fast,
    value: 1,
  );

  bool _sideways = false;
  bool _lingers = false;
  bool _hidden = false;
  Timer? _hideTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Size size = MediaQuery.sizeOf(context);
    final bool sideways =
        size.width > size.height &&
        size.shortestSide < OsdSizes.tabletShortestSide;
    final bool lingers =
        sideways && !MediaQuery.accessibleNavigationOf(context);
    if (sideways == _sideways && lingers == _lingers) return;
    _sideways = sideways;
    _lingers = lingers;
    if (lingers) {
      _touched();
    } else {
      // Upright again (or a screen reader came on): the chrome stays. This
      // runs while the page rebuilds anyway, so no setState.
      _hideTimer?.cancel();
      _hidden = false;
      _fade(show: true);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _shown.dispose();
    super.dispose();
  }

  /// A finger touched the page: the chrome stays another [linger].
  void _touched() {
    if (!_lingers) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(SidewaysChrome.linger, _hide);
  }

  void _hide() {
    if (!mounted) return;
    _hideTimer?.cancel();
    setState(() => _hidden = true);
    _fade(show: false);
  }

  void _show() {
    if (_hidden) setState(() => _hidden = false);
    _fade(show: true);
    _touched();
  }

  void _fade({required bool show}) {
    if (OsdMotion.reduced(context)) {
      _shown.value = show ? 1 : 0;
    } else {
      unawaited(show ? _shown.forward() : _shown.reverse());
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _touched(),
    child: widget.builder(context, (
      sideways: _sideways,
      shown: _shown,
      reveal: _hidden ? _show : null,
      hide: _lingers && !_hidden ? _hide : null,
    )),
  );
}
