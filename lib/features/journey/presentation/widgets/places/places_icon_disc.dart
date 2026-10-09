import 'package:flutter/widgets.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';

/// A filled glyph in a tinted disc, leading a row of the sheet.
class PlacesIconDisc extends StatelessWidget {
  const PlacesIconDisc({super.key, required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .16),
      shape: BoxShape.circle,
    ),
    child: OsdIcon(icon, size: 20, color: accent, fill: 1),
  );
}
