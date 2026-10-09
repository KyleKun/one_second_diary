import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/light_hairline.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A decorative hint: an icon, then text.
///
/// It is excluded from semantics: the same guidance is in the tiles' hints,
/// so a hint must never be cut. Two sit side by side at equal height
/// (`IntrinsicHeight` and `CrossAxisAlignment.stretch` at the call site)
/// while each [fits] its half; otherwise they stack, each whole ([maxLines]
/// null).
class HintChip extends StatelessWidget {
  const HintChip({
    super.key,
    required this.icon,
    required this.text,
    this.maxLines = 2,
  });

  static const Key surfaceKey = Key('hintChip.surface');

  static const double _paddingH = 12;
  static const double _icon = 18;
  static const double _gap = 6;

  /// Whether [text] shows whole in a chip [width] wide, in [context]'s
  /// text size and typography, on its 2 lines.
  static bool fits(
    BuildContext context, {
    required double width,
    required String text,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: context.typography.caption13),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 2,
    )..layout(maxWidth: math.max(0, width - 2 * _paddingH - _icon - _gap));
    final bool fits = !painter.didExceedMaxLines;
    painter.dispose();
    return fits;
  }

  final IconData icon;

  final String text;

  /// At most this many lines (2 side by side; null, stacked, for the whole
  /// hint).
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(OsdRadius.r14);
    return ExcludeSemantics(
      child: LightHairline(
        radius: radius,
        child: DecoratedBox(
          key: surfaceKey,
          decoration: BoxDecoration(color: colors.card, borderRadius: radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _paddingH,
              vertical: 10,
            ),
            child: Row(
              spacing: _gap,
              children: <Widget>[
                OsdIcon(icon, size: _icon, color: colors.mu),
                Expanded(
                  child: Text(
                    text,
                    maxLines: maxLines,
                    overflow: maxLines == null ? null : TextOverflow.ellipsis,
                    style: context.typography.caption13.copyWith(
                      color: colors.d2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
