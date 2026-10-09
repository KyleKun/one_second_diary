import 'package:flutter/widgets.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A fact about a place as a pill: a glyph and a short label.
class PlaceMetaChip extends StatelessWidget {
  const PlaceMetaChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.c2,
        borderRadius: BorderRadius.circular(OsdRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: <Widget>[
            OsdIcon(icon, size: 16, color: colors.mu),
            Text(
              label,
              style: context.typography.label13.copyWith(color: colors.tx),
            ),
          ],
        ),
      ),
    );
  }
}
