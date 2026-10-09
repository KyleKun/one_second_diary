import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_colors.dart';

/// The indeterminate hairline shown when a Today frame is slow to load.
/// Decorative.
class SlowLoadBar extends StatelessWidget {
  const SlowLoadBar({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 2,
      child: LinearProgressIndicator(
        minHeight: 2,
        color: context.colors.tx.withValues(alpha: .3),
        backgroundColor: const Color(0x00000000),
      ),
    ),
  );
}
