import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/shared/widgets/controls/orientation_thumb.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pop_switcher.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/light_hairline.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A tile that picks a profile's orientation.
///
/// - **Large**: a row of the [OrientationThumb], [name] over [detail], and a
///   radio glyph.
/// - **[OrientationOptionTile.compact]**: a column of the compact thumb
///   (which settles with a small bounce when chosen), name and detail.
///
/// Tapping the selected tile does nothing. Semantics: a radio in a mutually
/// exclusive group labelled "name, detail".
class OrientationOptionTile extends StatefulWidget {
  const OrientationOptionTile({
    super.key,
    required this.orientation,
    required this.name,
    required this.detail,
    required this.selected,
    required this.onTap,
  }) : compact = false;

  const OrientationOptionTile.compact({
    super.key,
    required this.orientation,
    required this.name,
    required this.detail,
    required this.selected,
    required this.onTap,
  }) : compact = true;

  static const Key surfaceKey = Key('orientationOptionTile.surface');

  /// The slot that centres the thumb.
  static const Key thumbSlotKey = Key('orientationOptionTile.thumbSlot');

  /// The large tile's radio glyph.
  static const Key checkKey = Key('orientationOptionTile.check');

  final VideoOrientation orientation;

  /// "Landscape" / "Portrait".
  final String name;

  /// "16:9 · wide" (large) or "16:9" (compact).
  final String detail;

  final bool selected;

  /// Called when the tile is chosen; not when it is already selected.
  final VoidCallback? onTap;

  final bool compact;

  @override
  State<OrientationOptionTile> createState() => _OrientationOptionTileState();
}

class _OrientationOptionTileState extends State<OrientationOptionTile>
    with SingleTickerProviderStateMixin {
  static const Duration _settleDuration = Duration(milliseconds: 240);
  static const Duration _checkDuration = Duration(milliseconds: 220);

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: _settleDuration,
    value: 1,
  );

  late final Animation<double> _scale =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 1,
            end: 1.06,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 40,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 1.06,
            end: 1,
          ).chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 60,
        ),
      ]).animate(_settle);

  @override
  void didUpdateWidget(OrientationOptionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.compact &&
        widget.selected &&
        !oldWidget.selected &&
        !OsdMotion.reduced(context)) {
      unawaited(_settle.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _choose() {
    if (widget.selected) return;
    unawaited(OsdHaptic.selection.play());
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final selected = widget.selected;
    final compact = widget.compact;
    final radius = BorderRadius.circular(
      compact ? OsdRadius.r18 : OsdRadius.r24,
    );
    final thumb = OrientationThumb(
      orientation: widget.orientation,
      selected: selected,
      compact: compact,
    );
    final Widget content = compact
        ? Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: <Widget>[
              SizedBox(
                key: OrientationOptionTile.thumbSlotKey,
                height: 56,
                child: Center(
                  child: ScaleTransition(scale: _scale, child: thumb),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.name,
                  maxLines: 1,
                  style: typography.titleSmall.copyWith(color: colors.tx),
                ),
              ),
              Text(
                widget.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.caption.copyWith(color: colors.mu),
              ),
            ],
          )
        : Row(
            spacing: 18,
            children: <Widget>[
              SizedBox(
                key: OrientationOptionTile.thumbSlotKey,
                width: 84,
                height: 64,
                child: Center(child: thumb),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 3,
                  children: <Widget>[
                    Text(
                      widget.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.title18Strong.copyWith(
                        color: colors.tx,
                      ),
                    ),
                    Text(
                      widget.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.body14.copyWith(color: colors.mu),
                    ),
                  ],
                ),
              ),
              KeyedSubtree(
                key: OrientationOptionTile.checkKey,
                child: OsdPopSwitcher(
                  duration: _checkDuration,
                  child: selected
                      ? OsdIcon(
                          OsdIcons.checkCircle,
                          key: const ValueKey<bool>(true),
                          fill: 1,
                          color: colors.tx,
                        )
                      : OsdIcon(
                          OsdIcons.radioButtonUnchecked,
                          key: const ValueKey<bool>(false),
                          color: colors.fa,
                        ),
                ),
              ),
            ],
          );
    return OsdPressable(
      onTap: _choose,
      pressScale: OsdPressScale.row.scale,
      overlay: OsdPressOverlay.none,
      borderRadius: radius,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      semanticsLabel: '${widget.name}, ${widget.detail}',
      excludeChildSemantics: true,
      child: LightHairline(
        radius: BorderRadius.circular(compact ? 16 : OsdRadius.r22),
        inset: 2,
        visible: !selected && !compact,
        child: AnimatedContainer(
          key: OrientationOptionTile.surfaceKey,
          duration: OsdMotion.d(context, OsdMotion.selection),
          curve: OsdMotion.curve(context, OsdMotion.selectionCurve),
          padding: compact
              ? const EdgeInsets.fromLTRB(12, 14, 12, 12)
              : const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected
                ? colors.sel
                : compact
                ? colors.c2
                : colors.card,
            border: Border.all(
              color: selected ? colors.tx : colors.tx.withValues(alpha: 0),
              width: 2,
            ),
            borderRadius: radius,
          ),
          child: content,
        ),
      ),
    );
  }
}
