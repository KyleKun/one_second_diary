import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';

/// A row that opens a page: an icon, a label (over a [subtitle], when it
/// has one) and a chevron.
class OsdNavRow extends StatelessWidget {
  const OsdNavRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;

  final String label;

  /// A second line under [label].
  final String? subtitle;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => OsdListRow(
    title: label,
    subtitle: subtitle,
    icon: icon,
    trailing: const OsdRowTrailing.chevron(),
    minHeight: OsdSizes.navRowHeight,
    gap: 12,
    onTap: onTap,
  );
}
