import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// How many clips a day holds, on its calendar cell. Its text scale is
/// clamped like the calendar's. It shows nothing for a single clip. The cell
/// places it and carries the semantics.
class ClipCountBadge extends StatelessWidget {
  const ClipCountBadge({super.key, required this.count});

  static const Key surfaceKey = Key('clipCountBadge.surface');

  /// The day's clip count.
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    final label = LocaleFormats.of(context).numbers.format(count);
    return ExcludeSemantics(
      child: DecoratedBox(
        key: surfaceKey,
        decoration: BoxDecoration(
          color: OsdMedia.scrim55,
          borderRadius: BorderRadius.circular(7),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                maxLines: 1,
                textScaler: OsdTextScale.scalerFor(
                  context,
                  OsdTextScaleRole.calendar,
                ),
                style: context.typography.microBadge.copyWith(
                  color: OsdMedia.onMedia,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
