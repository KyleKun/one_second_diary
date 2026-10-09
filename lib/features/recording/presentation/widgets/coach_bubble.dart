import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_camera.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The explanation under the orientation lock: a bubble whose width grows
/// with the text size, and an arrow up, drawn with the body as one path (two
/// translucent layers would show a seam). [emphasis] is bold and white.
class CoachBubble extends StatelessWidget {
  const CoachBubble({super.key, required this.text, this.emphasis});

  static const Key surfaceKey = Key('coachBubble.surface');

  /// The width at text size 1.
  static const double width = 230;

  final String text;

  /// The word shown bold, when [text] has it.
  final String? emphasis;

  @override
  Widget build(BuildContext context) {
    final TextStyle body = context.typography.footnote.copyWith(
      color: OsdCamera.bubbleText,
    );
    final double maxWidth =
        MediaQuery.sizeOf(context).width - 2 * OsdSpace.pageGutter;
    final String? emphasis = this.emphasis;
    final int at = emphasis == null || emphasis.isEmpty
        ? -1
        : text.indexOf(emphasis);
    return SizedBox(
      width: math.min(width * OsdTextScale.factorOf(context), maxWidth),
      child: DecoratedBox(
        key: surfaceKey,
        decoration: const ShapeDecoration(
          color: OsdCamera.bubble,
          shape: CoachBubbleShape(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OsdSpace.s14,
            vertical: OsdSpace.s12,
          ),
          child: at < 0
              ? Text(text, style: body)
              : Text.rich(
                  TextSpan(
                    style: body,
                    children: <TextSpan>[
                      TextSpan(text: text.substring(0, at)),
                      TextSpan(
                        text: emphasis,
                        style: body.copyWith(
                          color: OsdCamera.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: text.substring(at + emphasis!.length)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// The [CoachBubble]'s outline: a rounded box and an arrow up above its
/// top edge, its tip [arrowEndInset] from the end edge.
class CoachBubbleShape extends ShapeBorder {
  const CoachBubbleShape();

  /// Where the arrow's tip is, from the end edge.
  static const double arrowEndInset = 34;

  /// How far the tip is above the top edge.
  static const double arrowHeight = 8.5;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final double tipX = textDirection == TextDirection.rtl
        ? rect.left + arrowEndInset
        : rect.right - arrowEndInset;
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(OsdRadius.r14)),
      )
      ..moveTo(tipX - arrowHeight, rect.top)
      ..lineTo(tipX, rect.top - arrowHeight)
      ..lineTo(tipX + arrowHeight, rect.top)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
