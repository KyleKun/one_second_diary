import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Grows [child]'s hit area by [slop] without taking layout space: calendar
/// cells get hit areas that overlap the row gaps, colour swatches take their
/// half of the grid gaps.
///
/// A tap inside the slop reaches the child at the nearest point of its
/// bounds, so gesture detectors below see an ordinary tap. The ancestors must
/// cover the slop for the hit to arrive: a parent as tall as the child (a
/// `Row` of cells) needs its own slop.
///
/// Use it only where a full-size layout box would break the layout; the
/// default is `OsdPressable`'s padded hit area, which the tap-target
/// guidelines can measure.
class OsdHitSlop extends SingleChildRenderObjectWidget {
  const OsdHitSlop({super.key, required this.slop, super.child});

  /// How far the hit area reaches past each edge.
  final EdgeInsets slop;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHitSlop(slop);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderHitSlop).slop = slop;
}

class _RenderHitSlop extends RenderProxyBox {
  _RenderHitSlop(this._slop);

  static const double _edge = 1e-3;

  EdgeInsets _slop;
  set slop(EdgeInsets value) => _slop = value;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final bounds = Offset.zero & size;
    if (!_slop.inflateRect(bounds).contains(position)) return false;
    // Size.contains excludes the far edges, so stay just inside them.
    final inside = Offset(
      position.dx.clamp(0, math.max(0, size.width - _edge)),
      position.dy.clamp(0, math.max(0, size.height - _edge)),
    );
    if (hitTestChildren(result, position: inside) || hitTestSelf(inside)) {
      result.add(BoxHitTestEntry(this, inside));
      return true;
    }
    return false;
  }
}
