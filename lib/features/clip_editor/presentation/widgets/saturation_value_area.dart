import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_radius.dart';

/// The custom colour picker's square: the hue from white (left) to its
/// fullest (right), darkening to black at the bottom. A tap or a drag
/// picks the saturation (across) and the brightness (up); a white ring
/// marks the colour.
///
/// The hex field below is the picker's accessible input, so the square is
/// left out of semantics.
class SaturationValueArea extends StatelessWidget {
  const SaturationValueArea({
    super.key,
    required this.color,
    required this.onChanged,
  });

  static const double height = 180;
  static const double _ring = 24;
  static const double _ringWidth = 3;

  /// The colour shown; its hue paints the square.
  final HSVColor color;

  /// Called with the colour under the finger.
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = Size(constraints.maxWidth, height);
          void pick(Offset local) => onChanged(
            color
                .withSaturation((local.dx / size.width).clamp(0, 1))
                .withValue(1 - (local.dy / size.height).clamp(0, 1)),
          );
          // Two axis recognisers rather than one pan: the sheet's own
          // vertical drag has the same slop, and the inner one comes first,
          // so a drag in the square never pulls the sheet down.
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragDown: (DragDownDetails details) =>
                pick(details.localPosition),
            onVerticalDragUpdate: (DragUpdateDetails details) =>
                pick(details.localPosition),
            onHorizontalDragUpdate: (DragUpdateDetails details) =>
                pick(details.localPosition),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(OsdRadius.r16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: HSVColor.fromAHSV(1, color.hue, 1, 1).toColor(),
                      ),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              OsdMedia.onMedia,
                              Color(0x00FFFFFF),
                            ],
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Color(0x00000000),
                                OsdMedia.letterbox,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: color.saturation * size.width - _ring / 2,
                  top: (1 - color.value) * size.height - _ring / 2,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.toColor(),
                        border: Border.all(
                          color: OsdMedia.onMedia,
                          width: _ringWidth,
                        ),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(color: OsdMedia.swatchHairline),
                        ],
                      ),
                      child: const SizedBox.square(dimension: _ring),
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
