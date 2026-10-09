import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/dashed_border.dart';
import 'package:one_second_diary/shared/widgets/media/date_stamp.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_radius.dart';

/// The empty clip frame of Today: a dashed outline at the frame's size (from
/// the parent), with a [DateStamp.placeholder] at the bottom left (never
/// mirrored: stamp positions are physical).
///
/// One semantics node: [semanticsLabel].
class ClipPlaceholder extends StatelessWidget {
  const ClipPlaceholder({
    super.key,
    required this.stampText,
    required this.semanticsLabel,
  });

  static const Key stampKey = Key('clipPlaceholder.stamp');

  /// The formatted date, as the stamp would burn it.
  final String stampText;

  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: DashedBorder(
          color: colors.outline,
          borderRadius: BorderRadius.circular(OsdRadius.r20),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: 14,
                bottom: 10,
                right: 14,
                child: DateStamp.placeholder(stampText, key: stampKey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
