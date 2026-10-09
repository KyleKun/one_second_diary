import 'package:flutter/widgets.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/stat_label.dart';
import 'package:one_second_diary/shared/widgets/surfaces/stat_value.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A labelled value with a caption; tappable when it stands for a place.
class PlacesStatCard extends StatelessWidget {
  const PlacesStatCard({
    super.key,
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.emphasis,
    required this.sub,
    this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String value;

  /// The part of [value] drawn big.
  final String emphasis;
  final String sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    return OsdCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      semanticsLabel: onTap == null ? null : '$label, $value, $sub',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: <Widget>[
          StatLabel(icon: icon, accent: accent, label: label),
          StatValue(text: value, emphasis: emphasis),
          Text(
            sub,
            maxLines: 2,
            style: context.typography.caption.copyWith(color: colors.mu),
          ),
        ],
      ),
    );
  }
}
