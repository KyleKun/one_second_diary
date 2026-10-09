import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Where an `OsdPressable` inside an [OsdOverflowHitArea] reports the size
/// of its visual during layout.
final class OsdVisualSizeLink {
  /// The visual size of the last layout, or null before the first one.
  Size? visualSize;
}

/// Lays a control out at its visual size while its full hit area keeps
/// working.
///
/// The `OsdPressable` inside reports the size of its visual; this widget
/// takes that size and centres the control's full hit box over it, so
/// neighbouring targets may overlap. Taps and semantics keep the full box;
/// where targets overlap, the one painted last wins. It follows the visual at
/// every text size.
///
/// As with `OsdHitSlop`, ancestors as small as the visual block taps in the
/// overflow, so wrap the row in an `OsdHitSlop` that covers it.
class OsdOverflowHitArea extends StatefulWidget {
  const OsdOverflowHitArea({super.key, required this.child});

  /// The control (its `OsdPressable` reports the visual).
  final Widget child;

  /// The link the nearest [OsdOverflowHitArea] listens on, if any.
  static OsdVisualSizeLink? linkOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_VisualSizeScope>()?.link;

  @override
  State<OsdOverflowHitArea> createState() => _OsdOverflowHitAreaState();
}

class _OsdOverflowHitAreaState extends State<OsdOverflowHitArea> {
  final OsdVisualSizeLink _link = OsdVisualSizeLink();

  @override
  Widget build(BuildContext context) => _OverflowBox(
    link: _link,
    child: _VisualSizeScope(link: _link, child: widget.child),
  );
}

class _VisualSizeScope extends InheritedWidget {
  const _VisualSizeScope({required this.link, required super.child});

  final OsdVisualSizeLink link;

  @override
  bool updateShouldNotify(_VisualSizeScope oldWidget) => oldWidget.link != link;
}

class _OverflowBox extends SingleChildRenderObjectWidget {
  const _OverflowBox({required this.link, super.child});

  final OsdVisualSizeLink link;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderOverflowBox(link);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderOverflowBox).link = link;
}

class _RenderOverflowBox extends RenderShiftedBox {
  _RenderOverflowBox(this.link) : super(null);

  /// Room the hit box may take past the visual (a minimum-size target around
  /// a visual of any size, twice over for safety).
  static const double _room = 96;

  OsdVisualSizeLink link;

  BoxConstraints _widen(BoxConstraints constraints) => BoxConstraints(
    minWidth: constraints.minWidth,
    maxWidth: constraints.maxWidth + _room,
    minHeight: constraints.minHeight,
    maxHeight: constraints.maxHeight + _room,
  );

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(child.getDryLayout(_widen(constraints)));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    link.visualSize = null;
    child.layout(_widen(constraints), parentUsesSize: true);
    final visual = link.visualSize ?? child.size;
    size = constraints.constrain(
      Size(
        math.min(visual.width, child.size.width),
        math.min(visual.height, child.size.height),
      ),
    );
    (child.parentData! as BoxParentData).offset = Offset(
      (size.width - child.size.width) / 2,
      (size.height - child.size.height) / 2,
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    final offset = (child.parentData! as BoxParentData).offset;
    if (!(offset & child.size).contains(position)) return false;
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}
