import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The day of a clip on a picker tile: one line, its text scale clamped so
/// it stays inside the scrim. The tile places it and carries the semantics.
class ClipDateLabel extends StatelessWidget {
  const ClipDateLabel(this.text, {super.key});

  /// The short date.
  final String text;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textScaler: OsdTextScale.scalerFor(context, OsdTextScaleRole.mediaChrome),
      style: context.typography.sectionLabel.copyWith(color: OsdMedia.onMedia),
    ),
  );
}
