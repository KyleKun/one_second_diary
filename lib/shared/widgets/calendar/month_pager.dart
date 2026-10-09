import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Pages the calendar grid between months.
///
/// - A new [month] enters with a shared-axis X change: the old page slides
///   back and fades out while the new one comes from ahead and fades in.
///   "Ahead" is the reading direction: RTL mirrors it.
/// - The height follows the new page over `OsdMotion.standard` (a month of
///   4, 5 or 6 weeks); the old page leaves without holding the layout.
/// - A horizontal fling above [flingVelocity] pages: towards the reading
///   end is [onNext], back is [onPrevious]. With no month that way (null),
///   the page rubber-bands and springs back with a light impact.
/// - Reduced motion: a crossfade, nothing slides or bounces.
///
/// Nothing is clipped: the day rings reach outside the grid.
class MonthPager extends StatefulWidget {
  const MonthPager({
    super.key,
    required this.month,
    this.onPrevious,
    this.onNext,
    required this.child,
  });

  static Key pageKey(DiaryMonth month) =>
      ValueKey<(String, DiaryMonth)>(('monthPager.page', month));

  /// Pages at least this fast (logical px/s) change month.
  static const double flingVelocity = 300;

  static const Duration _change = Duration(milliseconds: 280);
  static const Duration _outFor = Duration(milliseconds: 120);
  static const Duration _inAfter = Duration(milliseconds: 80);
  static const double _shift = 30;
  static const Duration _bounce = Duration(milliseconds: 200);
  static const double _bounceShift = 12;

  final DiaryMonth month;

  /// Shows the month before; null on the first month.
  final VoidCallback? onPrevious;

  /// Shows the month after; null on this month.
  final VoidCallback? onNext;

  /// [month]'s page.
  final Widget child;

  @override
  State<MonthPager> createState() => _MonthPagerState();
}

class _MonthPagerState extends State<MonthPager>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: MonthPager._bounce,
  );

  /// +1 when the last change went forward in time, −1 back.
  int _towards = 1;

  /// The way the rubber band pulls: −1 towards the start edge, +1 the end.
  double _pull = 0;

  @override
  void didUpdateWidget(MonthPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.month != oldWidget.month) {
      _towards = widget.month.isAfter(oldWidget.month) ? 1 : -1;
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _flung(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < MonthPager.flingVelocity) return;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    // A leftward fling shows what is to the right: later in LTR.
    final bool forward = (velocity < 0) != rtl;
    final VoidCallback? page = forward ? widget.onNext : widget.onPrevious;
    if (page != null) {
      unawaited(OsdHaptic.selection.play());
      page();
      return;
    }
    unawaited(OsdHaptic.light.play());
    if (OsdMotion.reduced(context)) return;
    _pull = velocity < 0 ? -1 : 1;
    unawaited(_bounce.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = OsdMotion.reduced(context);
    final double ahead =
        _towards *
        MonthPager._shift *
        (Directionality.of(context) == TextDirection.rtl ? -1 : 1);
    return GestureDetector(
      // Screen readers page with the month arrows, not a pretend scroll.
      excludeFromSemantics: true,
      // Flings from the gaps and blanks count too.
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: _flung,
      child: AnimatedBuilder(
        animation: _bounce,
        builder: (BuildContext context, Widget? child) => Transform.translate(
          offset: Offset(
            _pull * MonthPager._bounceShift * _bounceCurve(_bounce.value),
            0,
          ),
          child: child,
        ),
        child: AnimatedSize(
          duration: OsdMotion.d(context, OsdMotion.standard),
          curve: OsdMotion.curve(context, OsdMotion.standardCurve),
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          child: AnimatedSwitcher(
            duration: OsdMotion.d(context, MonthPager._change),
            layoutBuilder: _layout,
            transitionBuilder: (Widget child, Animation<double> animation) {
              if (reduced) {
                return FadeTransition(opacity: animation, child: child);
              }
              final bool incoming =
                  child.key == MonthPager.pageKey(widget.month);
              return incoming
                  ? _Shift(
                      animation: _incoming(animation),
                      from: ahead,
                      child: child,
                    )
                  : _Shift(
                      animation: _outgoing(animation),
                      from: -ahead,
                      child: child,
                    );
            },
            child: KeyedSubtree(
              key: MonthPager.pageKey(widget.month),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }

  /// Out, then back: 0 → 1 → 0 over the bounce.
  static double _bounceCurve(double t) => t < .5
      ? Curves.easeOutCubic.transform(t * 2)
      : 1 - Curves.easeInOutCubic.transform((t - .5) * 2);

  /// The new page: in from [MonthPager._inAfter] to the end.
  ///
  /// The transition builder runs on every rebuild: a `CurveTween` keeps no
  /// listener of its own on [animation], where a `CurvedAnimation` made
  /// here would leak one each time.
  static Animation<double> _incoming(Animation<double> animation) =>
      animation.drive(
        CurveTween(
          curve: Interval(
            MonthPager._inAfter.inMicroseconds /
                MonthPager._change.inMicroseconds,
            1,
            curve: Curves.easeOutCubic,
          ),
        ),
      );

  /// The old page (its animation runs 1 → 0): gone after
  /// [MonthPager._outFor].
  static Animation<double> _outgoing(Animation<double> animation) =>
      animation.drive(
        CurveTween(
          curve: Interval(
            1 -
                MonthPager._outFor.inMicroseconds /
                    MonthPager._change.inMicroseconds,
            1,
            curve: Curves.easeInCubic,
          ),
        ),
      );

  /// The new page sizes the pager; old ones sit on top of it, out of the
  /// layout, while they leave.
  static Widget _layout(Widget? current, List<Widget> previous) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.topCenter,
    children: <Widget>[
      for (final Widget page in previous)
        Positioned(top: 0, left: 0, right: 0, child: page),
      ?current,
    ],
  );
}

/// A page fading and sliding along the axis: at [animation] 0 it is
/// [from] px away and invisible, at 1 in place.
class _Shift extends AnimatedWidget {
  const _Shift({
    required Animation<double> animation,
    required this.from,
    required this.child,
  }) : super(listenable: animation);

  final double from;
  final Widget child;

  Animation<double> get _animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _animation,
    child: Transform.translate(
      offset: Offset(from * (1 - _animation.value), 0),
      child: child,
    ),
  );
}
