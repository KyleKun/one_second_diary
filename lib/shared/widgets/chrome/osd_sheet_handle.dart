import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';

/// The sheet drag handle. Decorative, so excluded from semantics.
class OsdSheetHandle extends StatelessWidget {
  const OsdSheetHandle({super.key});

  static const Key barKey = Key('osdSheetHandle.bar');

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Center(
      child: SizedBox.fromSize(
        key: barKey,
        size: OsdSizes.sheetHandleSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.handle,
            borderRadius: BorderRadius.circular(OsdRadius.r2),
          ),
        ),
      ),
    ),
  );
}
