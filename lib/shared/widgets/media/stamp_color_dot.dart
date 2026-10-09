import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';

/// The date-stamp colour preview: a disc in the stamp [color], an OFF ring
/// outside it (no layout change), and a `colorize` glyph in the luminance
/// ink. Decorative: the card carries the label.
class StampColorDot extends StatelessWidget {
  const StampColorDot({super.key, required this.color});

  static const Key dotKey = Key('stampColorDot.dot');

  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DecoratedBox(
      key: dotKey,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(color: context.colors.off, spreadRadius: 1.5),
        ],
      ),
      child: SizedBox.square(
        dimension: 36,
        child: Center(
          child: OsdIcon(
            OsdIcons.colorize,
            size: 18,
            color: OsdMedia.inkOn(color),
          ),
        ),
      ),
    ),
  );
}
