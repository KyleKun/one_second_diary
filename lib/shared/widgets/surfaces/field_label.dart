import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The label above a field or control. No padding; a semantics header, up to
/// 2 lines.
class FieldLabel extends StatelessWidget {
  const FieldLabel({
    super.key,
    required this.label,
    this.textAlign = TextAlign.start,
  });

  final String label;

  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: context.typography.sectionLabelSoft.copyWith(
        color: context.colors.mu,
      ),
    ),
  );
}
