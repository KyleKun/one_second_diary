import 'package:flutter/material.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';

/// The little frame that pictures an orientation: a rectangle in the
/// orientation's shape with a glyph (the glyph belongs to the option, not the
/// state). Decorative.
class OrientationThumb extends StatelessWidget {
  const OrientationThumb({
    super.key,
    required this.orientation,
    required this.selected,
    this.compact = false,
  });

  static const Key surfaceKey = Key('orientationThumb.surface');

  final VideoOrientation orientation;

  /// Whether its option is selected.
  final bool selected;

  final bool compact;

  Size get _size => switch ((orientation, compact)) {
    (VideoOrientation.landscape, false) => const Size(84, 47),
    (VideoOrientation.portrait, false) => const Size(36, 64),
    (VideoOrientation.landscape, true) => const Size(60, 34),
    (VideoOrientation.portrait, true) => const Size(32, 56),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final duration = OsdMotion.d(context, OsdMotion.selection);
    final curve = OsdMotion.curve(context, OsdMotion.selectionCurve);
    final size = _size;
    return AnimatedContainer(
      key: surfaceKey,
      duration: duration,
      curve: curve,
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: selected
            ? colors.tx
            : compact
            ? colors.thumbOff
            : colors.off,
        borderRadius: BorderRadius.circular(OsdRadius.r8),
      ),
      child: Center(
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: selected ? colors.bg : colors.d2),
          duration: duration,
          curve: curve,
          builder: (context, color, _) => OsdIcon(
            orientation == VideoOrientation.landscape
                ? OsdIcons.landscape
                : OsdIcons.person,
            size: 18,
            color: color,
          ),
        ),
      ),
    );
  }
}
