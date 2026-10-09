import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_animated_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/light_hairline.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// One tab of [OsdSegmentedTabs].
@immutable
class OsdSegment {
  const OsdSegment({
    required this.icon,
    required this.accent,
    required this.label,
  });

  /// The glyph (filled when selected).
  final IconData icon;

  /// The glyph colour, in both states.
  final Color accent;

  final String label;
}

/// Segmented tabs with coloured icons.
///
/// A pill sits behind the selected segment and slides to the next one.
/// Labels scale down to fit; at large text scales the icons hide.
///
/// Segments' hit areas reach past the container. They read as "label" +
/// "Tab 1 of 3", `selected`. The current tab ignores taps. The content below
/// belongs to the page.
class OsdSegmentedTabs extends StatelessWidget {
  const OsdSegmentedTabs({
    super.key,
    required this.segments,
    required this.index,
    required this.onChanged,
  }) : assert(segments.length > 1, 'Tabs need two segments or more');

  static const Key containerKey = Key('osdSegmentedTabs.container');

  static const Key pillKey = Key('osdSegmentedTabs.pill');

  /// The segment at [index] (its hit area).
  static Key segmentKey(int index) =>
      ValueKey<(String, int)>(('osdSegmentedTabs.segment', index));

  static const double _outer = 46;
  static const double _padding = 4;
  static const double _segment = 38;
  static const Duration _iconFill = Duration(milliseconds: 200);

  final List<OsdSegment> segments;

  /// The selected tab.
  final int index;

  /// Called with the tab the user picks.
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = segments.length;
    final hideIcons =
        OsdTextScale.factorOf(context) > OsdTextScale.hideSegmentIconsAbove;
    final containerRadius = BorderRadius.circular(OsdRadius.r14);
    final localizations = MaterialLocalizations.of(context);
    return SizedBox(
      height: OsdSizes.minTap,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: (OsdSizes.minTap - _outer) / 2,
            bottom: (OsdSizes.minTap - _outer) / 2,
            child: LightHairline(
              radius: containerRadius,
              child: DecoratedBox(
                key: containerKey,
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: containerRadius,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(_padding),
                  child: AnimatedAlign(
                    alignment: AlignmentDirectional(
                      -1 + 2 * index / (count - 1),
                      0,
                    ),
                    duration: OsdMotion.d(context, OsdMotion.standard),
                    curve: OsdMotion.curve(context, OsdMotion.standardCurve),
                    child: FractionallySizedBox(
                      widthFactor: 1 / count,
                      heightFactor: 1,
                      child: DecoratedBox(
                        key: pillKey,
                        decoration: BoxDecoration(
                          color: colors.off,
                          borderRadius: BorderRadius.circular(OsdRadius.r10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            left: _padding,
            right: _padding,
            child: Row(
              children: <Widget>[
                for (var i = 0; i < count; i++)
                  Expanded(
                    child: OsdPressable(
                      key: segmentKey(i),
                      onTap: () {
                        if (i == index) return;
                        unawaited(OsdHaptic.selection.play());
                        onChanged(i);
                      },
                      pressScale: OsdPressScale.button.scale,
                      borderRadius: BorderRadius.circular(OsdRadius.r10),
                      selected: i == index,
                      semanticsLabel: segments[i].label,
                      semanticsHint: localizations.tabLabel(
                        tabIndex: i + 1,
                        tabCount: count,
                      ),
                      excludeChildSemantics: true,
                      child: SizedBox(
                        height: _segment,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 6,
                              children: <Widget>[
                                if (!hideIcons)
                                  OsdAnimatedIcon(
                                    segments[i].icon,
                                    fill: i == index ? 1 : 0,
                                    size: 18,
                                    color: segments[i].accent,
                                    duration: _iconFill,
                                  ),
                                Flexible(
                                  child: _Label(
                                    label: segments[i].label,
                                    selected: i == index,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: selected ? colors.tx : colors.mu),
      duration: OsdMotion.d(context, OsdSegmentedTabs._iconFill),
      builder: (context, color, _) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: (selected ? typography.label14Strong : typography.label14)
              .copyWith(color: color),
        ),
      ),
    );
  }
}
