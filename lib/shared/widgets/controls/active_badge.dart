import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The "Active" badge of the profile tile. `ProfileTile` pops it in and out
/// when the active profile changes.
class ActiveBadge extends StatelessWidget {
  const ActiveBadge({super.key, required this.label});

  static const Key surfaceKey = Key('activeBadge.surface');

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      key: surfaceKey,
      decoration: BoxDecoration(
        color: colors.tx,
        borderRadius: BorderRadius.circular(OsdRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          maxLines: 1,
          textScaler: OsdTextScale.scalerFor(
            context,
            OsdTextScaleRole.mediaChrome,
          ),
          style: context.typography.badge12.copyWith(color: colors.bg),
        ),
      ),
    );
  }
}
