import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The Settings tab's theme change: the new theme shows through a circle
/// growing from the switch's thumb, over a picture of the screen as it was.
///
/// [cover] takes the picture (the page under the root navigator's top
/// route, so the tabs and the nav are in it) and lays it over the whole
/// app, above every route; the caller then changes the theme and, once the
/// app shows it, calls [reveal]. [dismiss] takes the picture away at once
/// (the phone refused the change). A cover nobody reveals goes after a
/// second, so it can never stay. The app changes its theme at once under
/// the picture (`ThemeState.revealed`), and the system bars keep the old
/// theme's [systemBars] until the circle is half open.
///
/// The caller skips it under reduced motion (the app's crossfade shows the
/// theme); [cover] returns null when the screen can't be pictured, and the
/// crossfade shows it then too. The picture never takes a touch and is not
/// in the semantics tree.
final class ThemeReveal {
  ThemeReveal._(this._control);

  /// The picture over the app while it shows.
  static const Key coverKey = Key('themeReveal.cover');

  static const Duration duration = Duration(milliseconds: 450);
  static const Curve curve = Curves.easeInOutCubic;

  /// How long a cover waits for [reveal] before it reveals by itself.
  static const Duration _patience = Duration(seconds: 1);

  final _RevealControl _control;

  /// Pictures the screen and covers the app with it; the circle will grow
  /// from [center] (global). Null when there is no screen to picture.
  static ThemeReveal? cover(
    BuildContext context, {
    required Offset center,
    required SystemUiOverlayStyle systemBars,
  }) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    final RenderRepaintBoundary? screen = _screenOf(context);
    final RenderBox? overlayBox =
        overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null || screen == null || overlayBox == null) return null;
    if (!screen.hasSize || !overlayBox.hasSize) return null;
    bool painted = true;
    assert(() {
      painted = !screen.debugNeedsPaint;
      return true;
    }());
    if (!painted) return null;
    // A snapshot of the layer on the GPU, synchronous on purpose: the theme
    // changes right after it, before the next frame. It reads no file, but
    // test/core/ui_isolate_io_guard_test.dart flags every `.xSync(` call as
    // file IO, so it is torn off.
    final ui.Image Function({double pixelRatio}) snapshot = screen.toImageSync;
    final ui.Image picture;
    try {
      picture = snapshot(pixelRatio: View.of(context).devicePixelRatio);
    } on Object {
      return null;
    }
    final Rect area = MatrixUtils.transformRect(
      screen.getTransformTo(overlayBox),
      Offset.zero & screen.size,
    );
    final _RevealControl control = _RevealControl();
    final OverlayEntry entry = OverlayEntry(
      builder: (_) => _RevealCover(
        key: coverKey,
        picture: picture,
        area: area,
        center: overlayBox.globalToLocal(center),
        control: control,
        systemBars: systemBars,
      ),
    );
    // Once, whether or not the entry has been built yet.
    control.remove = () {
      if (control.removed) return;
      control.removed = true;
      entry.remove();
    };
    overlay.insert(entry);
    return ThemeReveal._(control);
  }

  /// Opens the circle: the new theme shows through it, then the cover goes.
  void reveal() => _control.reveal();

  /// Takes the cover away at once.
  void dismiss() => _control.remove?.call();

  /// Whether the cover is still over the app.
  bool get isShown => !_control.removed;

  /// The outermost repaint boundary below the root navigator above
  /// [context]: its top route's page, from the status bar to the nav.
  static RenderRepaintBoundary? _screenOf(BuildContext context) {
    final NavigatorState root = Navigator.of(context, rootNavigator: true);
    RenderRepaintBoundary? found;
    context.visitAncestorElements((Element element) {
      if (element is StatefulElement && identical(element.state, root)) {
        return false;
      }
      if (element.widget is RepaintBoundary) {
        found = element.renderObject as RenderRepaintBoundary?;
      }
      return true;
    });
    return found;
  }
}

/// What the owner of a cover can ask of it, before or after the cover's
/// first frame.
final class _RevealControl {
  /// Takes the cover out of the overlay.
  VoidCallback? remove;

  bool removed = false;

  /// Starts the circle; set while the cover is on screen.
  VoidCallback? _start;

  bool _asked = false;

  void reveal() {
    _asked = true;
    _start?.call();
  }
}

class _RevealCover extends StatefulWidget {
  const _RevealCover({
    super.key,
    required this.picture,
    required this.area,
    required this.center,
    required this.control,
    required this.systemBars,
  });

  final ui.Image picture;

  /// The old theme's system bars, until the circle is half open.
  final SystemUiOverlayStyle systemBars;

  /// Where the picture sits, in the overlay.
  final Rect area;

  /// The circle's centre, in the overlay.
  final Offset center;

  final _RevealControl control;

  @override
  State<_RevealCover> createState() => _RevealCoverState();
}

class _RevealCoverState extends State<_RevealCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _circle = AnimationController(
    vsync: this,
    duration: ThemeReveal.duration,
  );
  late final Animation<double> _curved = _circle.drive(
    CurveTween(curve: ThemeReveal.curve),
  );
  Timer? _patience;

  @override
  void initState() {
    super.initState();
    widget.control._start = _start;
    if (widget.control._asked) {
      _start();
    } else {
      _patience = Timer(ThemeReveal._patience, widget.control.reveal);
    }
  }

  void _start() {
    if (_circle.isAnimating || _circle.isCompleted) return;
    _patience?.cancel();
    unawaited(
      _circle.forward().whenComplete(() => widget.control.remove?.call()),
    );
  }

  @override
  void dispose() {
    _patience?.cancel();
    widget.control._start = null;
    _circle.dispose();
    widget.picture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget picture = IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _RevealPainter(
              picture: widget.picture,
              area: widget.area,
              center: widget.center,
              progress: _curved,
            ),
          ),
        ),
      ),
    );
    // The cover is the topmost layer: while it annotates the bars, they
    // keep the old theme; from half way the pages below say the new one.
    return AnimatedBuilder(
      animation: _curved,
      builder: (BuildContext context, Widget? child) => _curved.value < .5
          ? AnnotatedRegion<SystemUiOverlayStyle>(
              value: widget.systemBars,
              child: child!,
            )
          : child!,
      child: picture,
    );
  }
}

/// The old screen with a circular hole of [progress] × the distance from
/// [center] to the farthest corner.
class _RevealPainter extends CustomPainter {
  _RevealPainter({
    required this.picture,
    required this.area,
    required this.center,
    required this.progress,
  }) : super(repaint: progress);

  final ui.Image picture;
  final Rect area;
  final Offset center;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double farthest = <Offset>[
      area.topLeft,
      area.topRight,
      area.bottomLeft,
      area.bottomRight,
    ].map((Offset corner) => (corner - center).distance).reduce(math.max);
    final Path outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(area)
      ..addOval(
        Rect.fromCircle(center: center, radius: farthest * progress.value),
      );
    canvas
      ..save()
      ..clipPath(outside)
      ..drawImageRect(
        picture,
        Offset.zero & Size(picture.width.toDouble(), picture.height.toDouble()),
        area,
        Paint()..filterQuality = FilterQuality.medium,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_RevealPainter oldDelegate) =>
      oldDelegate.picture != picture ||
      oldDelegate.area != area ||
      oldDelegate.center != center;
}
