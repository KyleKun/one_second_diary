import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/controls/tag_chip.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// A clip's tags as read-only chips that wrap onto new lines, or, with
/// [maxLines] 1, one line that fades out at the end (captions).
class TagChipRow extends StatelessWidget {
  const TagChipRow({
    super.key,
    required this.tags,
    required this.colorOf,
    this.compact = true,
    this.maxLines,
    this.onTap,
  });

  final List<String> tags;

  /// The colour of each tag (`TagColors.colorOf`).
  final Color Function(String tag) colorOf;

  final bool compact;

  /// With 1, the chips stay on one line and the row fades at the end.
  final int? maxLines;

  /// Called with the tag tapped; null makes the chips plain text.
  final void Function(String tag)? onTap;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final List<Widget> chips = <Widget>[
      for (final String tag in tags)
        TagChip(
          label: tag,
          color: colorOf(tag),
          compact: compact,
          onTap: onTap == null ? null : () => onTap!(tag),
        ),
    ];
    if (maxLines == 1) {
      return ShaderMask(
        shaderCallback: (Rect bounds) => const LinearGradient(
          colors: <Color>[Colors.white, Colors.white, Colors.transparent],
          stops: <double>[0, .9, 1],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: OsdSpace.s6,
            children: chips,
          ),
        ),
      );
    }
    return Wrap(spacing: OsdSpace.s6, runSpacing: OsdSpace.s6, children: chips);
  }
}
