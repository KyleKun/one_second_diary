import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pop_switcher.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_surface.dart';

/// A date-stamp colour swatch: a disc in [color] with an inner hairline.
/// **Selected:** no hairline; a TX ring outside a gap in the surface colour
/// (drawn as spread shadows, so no layout change) and a check in the
/// luminance ink (`OsdMedia.inkOn`).
///
/// The swatch takes no extra layout for its hit area: `SwatchGrid` gives each
/// swatch its cell plus half the gaps. `CustomSwatch` builds on it with
/// [hairline], [glyph] and [badge].
class ColorSwatchButton extends StatefulWidget {
  const ColorSwatchButton({
    super.key,
    required this.color,
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
    this.diameter = 34,
    this.hairline = true,
    this.glyph,
    this.badge,
  });

  static const Key discKey = Key('colorSwatchButton.disc');

  static const Key hairlineKey = Key('colorSwatchButton.hairline');

  static const Key checkKey = Key('colorSwatchButton.check');

  final Color color;

  final bool selected;

  /// The colour's name.
  final String semanticsLabel;

  final VoidCallback? onTap;

  /// The disc diameter (the grid shrinks it on narrow screens).
  final double diameter;

  /// Whether the unselected disc gets the inner hairline.
  final bool hairline;

  /// A glyph shown while unselected.
  final Widget? glyph;

  /// A badge at the bottom-end.
  final Widget? badge;

  @override
  State<ColorSwatchButton> createState() => _ColorSwatchButtonState();
}

class _ColorSwatchButtonState extends State<ColorSwatchButton>
    with SingleTickerProviderStateMixin {
  static const Duration _grow = OsdMotion.selection;
  static const Duration _fade = Duration(milliseconds: 120);
  static const double _ring = 4;
  static const double _gap = 2;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _grow,
    reverseDuration: _fade,
    value: widget.selected ? 1 : 0,
  );

  @override
  void didUpdateWidget(ColorSwatchButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected) return;
    _controller
      ..duration = OsdMotion.d(context, _grow)
      ..reverseDuration = OsdMotion.d(context, _fade);
    unawaited(
      widget.selected ? _controller.forward(from: 0) : _controller.reverse(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<BoxShadow>? _rings(OsdColors colors, Color gap) {
    final value = _controller.value;
    if (value == 0) return null;
    final growing =
        _controller.status == AnimationStatus.forward ||
        _controller.status == AnimationStatus.completed;
    final spread = growing && !OsdMotion.reduced(context)
        ? OsdMotion.badgeInCurve.transform(value)
        : 1.0;
    final alpha = growing ? 1.0 : value;
    return <BoxShadow>[
      BoxShadow(
        color: colors.tx.withValues(alpha: colors.tx.a * alpha),
        spreadRadius: _ring * spread,
      ),
      BoxShadow(
        color: gap.withValues(alpha: gap.a * alpha),
        spreadRadius: _gap * spread,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gap = OsdSurface.of(context).color(colors);
    final selected = widget.selected;
    final badge = widget.badge;
    return OsdPressable(
      onTap: widget.onTap,
      haptic: OsdHaptic.selection,
      pressScale: OsdPressScale.icon.scale,
      overlay: OsdPressOverlay.none,
      shape: BoxShape.circle,
      minHitSize: 0,
      selected: selected,
      semanticsLabel: widget.semanticsLabel,
      excludeChildSemantics: true,
      child: SizedBox.square(
        dimension: widget.diameter,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => DecoratedBox(
                  key: ColorSwatchButton.discKey,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: _rings(colors, gap),
                  ),
                  child: child,
                ),
                child: Center(
                  child: OsdPopSwitcher(
                    duration: OsdMotion.fast,
                    child: selected
                        ? OsdIcon(
                            OsdIcons.check,
                            key: ColorSwatchButton.checkKey,
                            size: 18,
                            color: OsdMedia.inkOn(widget.color),
                          )
                        : widget.glyph,
                  ),
                ),
              ),
            ),
            if (widget.hairline && !selected)
              const Positioned.fill(
                child: DecoratedBox(
                  key: ColorSwatchButton.hairlineKey,
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: OsdMedia.swatchHairline),
                    ),
                  ),
                ),
              ),
            if (badge != null)
              PositionedDirectional(end: 0, bottom: 0, child: badge),
          ],
        ),
      ),
    );
  }
}
