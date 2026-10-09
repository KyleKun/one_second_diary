import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_colors.dart';

/// A 1 px LN line. Between rows in a card it is inset from the start edge
/// (mirrored in RTL); [OsdDivider.full] spans the width (pinned bars, footers
/// under scrolling content).
class OsdDivider extends StatelessWidget {
  const OsdDivider({super.key, this.indent = 16});

  const OsdDivider.full({super.key}) : indent = 0;

  static const Key lineKey = Key('osdDivider.line');

  /// The start inset.
  final double indent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(start: indent),
    child: SizedBox(
      key: lineKey,
      height: 1,
      width: double.infinity,
      child: ColoredBox(color: context.colors.ln),
    ),
  );
}
