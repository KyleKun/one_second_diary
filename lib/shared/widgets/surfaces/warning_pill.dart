import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_tints.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A yellow-tinted pill hugging a `warning` glyph and a label.
class WarningPill extends StatelessWidget {
  const WarningPill({super.key, required this.label});

  static const Key surfaceKey = Key('warningPill.surface');

  final String label;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.yellowInk;
    return DecoratedBox(
      key: surfaceKey,
      decoration: BoxDecoration(
        color: OsdTints.yellowTint12,
        borderRadius: BorderRadius.circular(OsdRadius.r12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: <Widget>[
            OsdIcon(OsdIcons.warning, size: 18, color: ink),
            Flexible(
              child: Text(
                label,
                style: context.typography.label14.copyWith(color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
