import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_shadows.dart';
import 'package:one_second_diary/theme/osd_surface.dart';

/// The custom colour picker's hue slider. A tap or a drag picks the hue
/// under the thumb's centre.
///
/// The hex field below is the picker's accessible input, so the slider is
/// left out of semantics.
class HueSlider extends StatelessWidget {
  const HueSlider({super.key, required this.hue, required this.onChanged});

  static const double _thumb = 28;
  static const double _track = 24;
  static const double _ring = 2;

  /// The rainbow, red to red, every 60°.
  static final List<Color> _rainbow = <Color>[
    for (double hue = 0; hue <= 360; hue += 60)
      HSVColor.fromAHSV(1, hue % 360, 1, 1).toColor(),
  ];

  /// 0–360.
  final double hue;

  /// Called with the hue under the finger.
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color ring = OsdSurface.of(context).color(context.colors);
    return ExcludeSemantics(
      child: SizedBox(
        height: _thumb,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double span = constraints.maxWidth - _thumb;
            void pick(Offset local) =>
                onChanged(((local.dx - _thumb / 2) / span).clamp(0, 1) * 360);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragDown: (DragDownDetails details) =>
                  pick(details.localPosition),
              onHorizontalDragUpdate: (DragUpdateDetails details) =>
                  pick(details.localPosition),
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned(
                    left: 0,
                    right: 0,
                    top: (_thumb - _track) / 2,
                    height: _track,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(OsdRadius.r12),
                        gradient: LinearGradient(colors: _rainbow),
                      ),
                    ),
                  ),
                  Positioned(
                    left: hue / 360 * span,
                    top: 0,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: OsdMedia.onMedia,
                          boxShadow: OsdShadows.ring(
                            ring: ring,
                            gap: ring,
                            ringSpread: _ring,
                            gapSpread: _ring,
                          ),
                        ),
                        child: const SizedBox.square(dimension: _thumb),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
