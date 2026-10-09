import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_overflow_hit_area.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_tints.dart';

/// The overlay a pressed or hovered surface gets.
enum OsdPressOverlay {
  /// SEL over neutral fills and transparent surfaces.
  sel,

  /// A dark tint over CO and RED fills.
  darken,

  /// No overlay: the component draws its own pressed state.
  none,
}

/// How keyboard focus shows.
enum OsdFocusStyle {
  /// Standalone controls: an outer TX ring, just outside the edge.
  ring,

  /// Rows inside a clipped card: a SEL fill and an inner TX border.
  inner,

  /// The child draws focus itself (read [OsdPressable.isFocused]), e.g. the
  /// nav ring around the active pill.
  custom,
}

/// Makes a non-stock surface tappable.
///
/// Press feedback is a scale (the category values of [OsdPressScale]) and an
/// overlay, never a ripple: the scale goes in over `OsdMotion.pressIn` and
/// back over `OsdMotion.pressOut`; the overlay fades over `overlayIn` /
/// `overlayOut`. Under reduced motion the press still scales, but never below
/// 0.97.
///
/// The hit area is at least [minHitSize] square: a smaller visual is centred
/// in a transparent box that also takes the layout space, like
/// `MaterialTapTargetSize.padded`. Tight constraints reach the child
/// unchanged, so full-width buttons stay full width.
///
/// A pressable with neither [onTap] nor [onLongPress] is disabled: no
/// feedback, `Semantics(enabled: false)` and skipped by focus traversal. The
/// component draws its own disabled look (usually [disabledOpacity]).
class OsdPressable extends StatefulWidget {
  const OsdPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onDisabledTap,
    this.pressScale = .97,
    this.overlay = OsdPressOverlay.sel,
    this.borderRadius = BorderRadius.zero,
    this.shape = BoxShape.rectangle,
    this.focusStyle = OsdFocusStyle.ring,
    this.haptic,
    this.minHitSize = OsdSizes.minTap,
    this.semanticsLabel,
    this.semanticsHint,
    this.semanticsTapHint,
    this.semanticsLongPressHint,
    this.tooltip,
    this.isButton = true,
    this.selected,
    this.checked,
    this.toggled,
    this.inMutuallyExclusiveGroup,
    this.excludeChildSemantics = false,
    this.customSemanticsActions,
    this.autofocus = false,
    this.focusNode,
    this.opacity = 1,
  });

  /// The disabled look of most components.
  static const double disabledOpacity = .4;

  /// The [opacity] of a component that is [enabled] or not. Components pass
  /// it to their pressable rather than toggling an `Opacity` wrapper: a
  /// toggled wrapper rebuilds the subtree, so a control that turns off
  /// mid-animation would restart its state.
  static double opacityFor({required bool enabled}) =>
      enabled ? 1 : disabledOpacity;

  /// The painted surface: the child with its overlay and focus ring.
  static const Key surfaceKey = Key('osdPressable.surface');

  /// Whether the nearest enclosing [OsdPressable] is pressed, for visuals that
  /// change more than the overlay (a circle blending TX, a tile fill).
  static bool isPressed(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PressScope>()?.pressed ??
      false;

  /// Whether the nearest enclosing [OsdPressable] shows keyboard focus.
  static bool isFocused(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PressScope>()?.focused ??
      false;

  final Widget child;

  /// Called on a tap, or when the focused control is activated with a key.
  final VoidCallback? onTap;

  final VoidCallback? onLongPress;

  /// Called when a disabled pressable is tapped (e.g. a disabled chip that
  /// explains why in a snackbar). It gives no press feedback.
  final VoidCallback? onDisabledTap;

  /// The scale at full press, usually `OsdPressScale.x.scale`. Null presses
  /// without scaling (rows inside cards).
  final double? pressScale;

  /// The pressed and hover overlay.
  final OsdPressOverlay overlay;

  /// The corner radius of the overlay and the focus ring.
  final BorderRadius borderRadius;

  /// A circle for round buttons; [borderRadius] is then ignored.
  final BoxShape shape;

  final OsdFocusStyle focusStyle;

  /// Played on tap.
  final OsdHaptic? haptic;

  /// The smallest hit area, in both directions.
  final double minHitSize;

  /// The semantics label. Defaults to [tooltip]; otherwise the child's text
  /// makes the label.
  final String? semanticsLabel;

  final String? semanticsHint;

  /// What a tap does, as a phrase ("switch profile"): the platform says the
  /// gesture ("double-tap to switch profile"), so a label never spells it.
  /// Null keeps the platform's own ("double-tap to activate").
  final String? semanticsTapHint;

  /// What a long press does, as a phrase ("show options").
  final String? semanticsLongPressHint;

  /// A tooltip, which is also the semantics label. Icon-only controls always
  /// have one.
  final String? tooltip;

  /// Whether the node is a button. Radio rows and tiles set their own roles.
  final bool isButton;

  /// Semantics `selected` (tabs, selected tiles).
  final bool? selected;

  /// Semantics `checked` (radios).
  final bool? checked;

  /// Semantics `toggled` (switch rows).
  final bool? toggled;

  /// Semantics `inMutuallyExclusiveGroup` (radios, single-choice tiles).
  final bool? inMutuallyExclusiveGroup;

  /// Whether the child's own semantics are replaced by [semanticsLabel].
  final bool excludeChildSemantics;

  /// Extra semantics actions, e.g. a long press's "Edit profile" for screen
  /// reader users.
  final Map<CustomSemanticsAction, VoidCallback>? customSemanticsActions;

  final bool autofocus;

  /// The whole pressable's opacity, inside its semantics node (the disabled
  /// look: [opacityFor]).
  final double opacity;

  final FocusNode? focusNode;

  @override
  State<OsdPressable> createState() => _OsdPressableState();
}

class _OsdPressableState extends State<OsdPressable> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void didUpdateWidget(OsdPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) {
      _pressed = false;
      _hovered = false;
    }
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    if (!_enabled) {
      widget.onDisabledTap?.call();
      return;
    }
    final haptic = widget.haptic;
    if (haptic != null) unawaited(haptic.play());
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = _enabled;
    final pressed = enabled && _pressed;
    final showOverlay =
        widget.overlay != OsdPressOverlay.none &&
        enabled &&
        (pressed || _hovered);
    final overlayColor = widget.overlay == OsdPressOverlay.darken
        ? OsdTints.pressOnFill
        : colors.sel;
    final scale = widget.pressScale == null || !pressed
        ? 1.0
        : OsdMotion.reduced(context)
        ? math.max(widget.pressScale!, .97)
        : widget.pressScale!;

    Widget visual = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: showOverlay ? 1 : 0),
      duration: OsdMotion.d(
        context,
        showOverlay ? OsdMotion.overlayIn : OsdMotion.overlayOut,
      ),
      curve: OsdMotion.curve(context, Curves.easeOut),
      builder: (context, overlay, child) => CustomPaint(
        key: OsdPressable.surfaceKey,
        foregroundPainter: _PressablePainter(
          overlayColor: overlayColor.withValues(
            alpha: overlayColor.a * overlay,
          ),
          focus: enabled && _focused ? widget.focusStyle : null,
          ink: colors.tx,
          sel: colors.sel,
          shape: widget.shape,
          borderRadius: widget.borderRadius,
        ),
        child: child,
      ),
      child: _PressScope(
        pressed: pressed,
        focused: enabled && _focused,
        child: widget.excludeChildSemantics
            ? ExcludeSemantics(child: widget.child)
            : widget.child,
      ),
    );

    visual = AnimatedScale(
      scale: scale,
      duration: OsdMotion.d(
        context,
        pressed ? OsdMotion.pressIn : OsdMotion.pressOut,
      ),
      curve: OsdMotion.curve(
        context,
        pressed ? OsdMotion.pressInCurve : OsdMotion.pressOutCurve,
      ),
      child: visual,
    );

    Widget result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTap: enabled
          ? (widget.onTap == null ? null : _handleTap)
          : widget.onDisabledTap,
      onLongPress: enabled ? widget.onLongPress : null,
      child: _MinHitArea(minSize: widget.minHitSize, child: visual),
    );

    result = FocusableActionDetector(
      enabled: enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _handleTap();
            return null;
          },
        ),
      },
      child: result,
    );

    final tooltip = widget.tooltip;
    if (tooltip != null) {
      result = Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: result,
      );
    }

    return Semantics(
      container: true,
      button: widget.isButton,
      enabled: enabled,
      selected: widget.selected,
      checked: widget.checked,
      toggled: widget.toggled,
      inMutuallyExclusiveGroup: widget.inMutuallyExclusiveGroup,
      label: widget.semanticsLabel ?? tooltip,
      hint: widget.semanticsHint,
      onTapHint: enabled ? widget.semanticsTapHint : null,
      onLongPressHint: enabled && widget.onLongPress != null
          ? widget.semanticsLongPressHint
          : null,
      onTap: enabled && widget.onTap != null ? _handleTap : null,
      onLongPress: enabled ? widget.onLongPress : null,
      customSemanticsActions: enabled ? widget.customSemanticsActions : null,
      child: Opacity(opacity: widget.opacity, child: result),
    );
  }
}

class _PressScope extends InheritedWidget {
  const _PressScope({
    required this.pressed,
    required this.focused,
    required super.child,
  });

  final bool pressed;
  final bool focused;

  @override
  bool updateShouldNotify(_PressScope oldWidget) =>
      oldWidget.pressed != pressed || oldWidget.focused != focused;
}

class _PressablePainter extends CustomPainter {
  const _PressablePainter({
    required this.overlayColor,
    required this.focus,
    required this.ink,
    required this.sel,
    required this.shape,
    required this.borderRadius,
  });

  final Color overlayColor;
  final OsdFocusStyle? focus;
  final Color ink;
  final Color sel;
  final BoxShape shape;
  final BorderRadius borderRadius;

  RRect _visual(Size size) {
    final rect = Offset.zero & size;
    return shape == BoxShape.circle
        ? RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2))
        : borderRadius.toRRect(rect);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final visual = _visual(size);
    if (overlayColor.a > 0) {
      canvas.drawRRect(visual, Paint()..color = overlayColor);
    }
    switch (focus) {
      case null || OsdFocusStyle.custom:
        break;
      case OsdFocusStyle.ring:
        canvas.drawDRRect(
          visual.inflate(5),
          visual.inflate(3),
          Paint()..color = ink,
        );
      case OsdFocusStyle.inner:
        canvas
          ..drawRRect(visual, Paint()..color = sel)
          ..drawDRRect(visual, visual.deflate(2), Paint()..color = ink);
    }
  }

  @override
  bool shouldRepaint(_PressablePainter oldDelegate) =>
      oldDelegate.overlayColor != overlayColor ||
      oldDelegate.focus != focus ||
      oldDelegate.ink != ink ||
      oldDelegate.sel != sel ||
      oldDelegate.shape != shape ||
      oldDelegate.borderRadius != borderRadius;
}

/// Lays the child out with the incoming constraints, then grows to at least
/// [minSize] square with the child centred.
class _MinHitArea extends SingleChildRenderObjectWidget {
  const _MinHitArea({required this.minSize, super.child});

  final double minSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMinHitArea(minSize)..link = OsdOverflowHitArea.linkOf(context);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMinHitArea renderObject,
  ) => renderObject
    ..minSize = minSize
    ..link = OsdOverflowHitArea.linkOf(context);
}

class _RenderMinHitArea extends RenderShiftedBox {
  _RenderMinHitArea(this._minSize) : super(null);

  /// Where the visual's size goes when an `OsdOverflowHitArea` lays the
  /// control out at its visual size.
  OsdVisualSizeLink? link;

  double _minSize;
  double get minSize => _minSize;
  set minSize(double value) {
    if (value == _minSize) return;
    _minSize = value;
    markNeedsLayout();
  }

  Size _grow(Size child, BoxConstraints constraints) => constraints.constrain(
    Size(math.max(child.width, minSize), math.max(child.height, minSize)),
  );

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(child?.getMinIntrinsicWidth(height) ?? 0, minSize);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      math.max(child?.getMaxIntrinsicWidth(height) ?? 0, minSize);

  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(child?.getMinIntrinsicHeight(width) ?? 0, minSize);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(child?.getMaxIntrinsicHeight(width) ?? 0, minSize);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.constrain(Size.square(minSize));
    return _grow(child.getDryLayout(constraints), constraints);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size.square(minSize));
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    link?.visualSize = child.size;
    size = _grow(child.size, constraints);
    (child.parentData! as BoxParentData).offset = Alignment.center.alongOffset(
      size - child.size as Offset,
    );
  }
}
