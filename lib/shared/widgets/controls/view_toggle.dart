import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';

/// One view of a [ViewToggle].
@immutable
class ViewToggleOption {
  const ViewToggleOption({required this.icon, required this.tooltip});

  final IconData icon;

  /// The tooltip, which is also the semantics label.
  final String tooltip;
}

/// The icon-only segmented control of the Diary title row: a track of
/// segments with a thumb that slides behind the selected one.
///
/// Each segment's tap target is centred on its visual and larger than it: the
/// targets reach above and below the track (the widget lays out at their
/// height) and neighbouring targets overlap. They form a toggle group:
/// `selected`, mutually exclusive, the tooltip as label.
class ViewToggle extends StatelessWidget {
  const ViewToggle({
    super.key,
    required this.options,
    required this.index,
    required this.onChanged,
  }) : assert(options.length > 1, 'A toggle needs two views or more');

  static const Key trackKey = Key('viewToggle.track');

  static const Key thumbKey = Key('viewToggle.thumb');

  /// The segment at [index] (its tap target).
  static Key segmentKey(int index) =>
      ValueKey<(String, int)>(('viewToggle.segment', index));

  static const double _pad = 3;
  static const double _segmentWidth = 42;
  static const double _segmentHeight = 34;
  static const double _trackHeight = 40;

  final List<ViewToggleOption> options;

  /// The selected view.
  final int index;

  /// Called with the view the user picks.
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const hit = OsdSizes.minTap;
    final trackWidth = 2 * _pad + _segmentWidth * options.length;
    final duration = OsdMotion.d(context, OsdMotion.standard);
    final curve = OsdMotion.curve(context, OsdMotion.standardCurve);
    return SizedBox(
      width: trackWidth,
      height: hit,
      child: Stack(
        children: <Widget>[
          PositionedDirectional(
            start: 0,
            top: (hit - _trackHeight) / 2,
            width: trackWidth,
            height: _trackHeight,
            child: DecoratedBox(
              key: trackKey,
              decoration: BoxDecoration(
                color: colors.btn,
                borderRadius: BorderRadius.circular(OsdRadius.r12),
              ),
            ),
          ),
          AnimatedPositionedDirectional(
            duration: duration,
            curve: curve,
            start: _pad + _segmentWidth * index,
            top: (hit - _segmentHeight) / 2,
            width: _segmentWidth,
            height: _segmentHeight,
            child: DecoratedBox(
              key: thumbKey,
              decoration: BoxDecoration(
                color: colors.off,
                borderRadius: BorderRadius.circular(OsdRadius.r9),
              ),
            ),
          ),
          for (var i = 0; i < options.length; i++)
            PositionedDirectional(
              start: _segmentWidth * i,
              top: 0,
              width: hit,
              height: hit,
              child: OsdPressable(
                key: segmentKey(i),
                onTap: () {
                  if (i == index) return;
                  unawaited(OsdHaptic.selection.play());
                  onChanged(i);
                },
                pressScale: OsdPressScale.button.scale,
                overlay: OsdPressOverlay.none,
                borderRadius: BorderRadius.circular(OsdRadius.r9),
                tooltip: options[i].tooltip,
                selected: i == index,
                inMutuallyExclusiveGroup: true,
                child: SizedBox(
                  width: _segmentWidth,
                  height: _segmentHeight,
                  child: Center(
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        end: i == index ? colors.tx : colors.mu,
                      ),
                      duration: OsdMotion.d(context, OsdMotion.fast),
                      builder: (context, color, _) =>
                          OsdIcon(options[i].icon, size: 20, color: color),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
