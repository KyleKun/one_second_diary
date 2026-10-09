import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';

/// The pair of dialog buttons, side by side. Put the Neutral "Cancel" first
/// and the Primary or Destructive confirm second.
///
/// At large text scales the buttons stack, cancel first.
class OsdDialogActionRow extends StatelessWidget {
  const OsdDialogActionRow({
    super.key,
    required this.cancel,
    required this.confirm,
    this.topGap = 8,
  });

  final Widget cancel;

  final Widget confirm;

  /// The extra space above the row.
  final double topGap;

  @override
  Widget build(BuildContext context) {
    final stacked =
        OsdTextScale.factorOf(context) > OsdTextScale.stackButtonRowsAbove;
    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: <Widget>[cancel, confirm],
            )
          : Row(
              spacing: 10,
              children: <Widget>[
                Expanded(child: cancel),
                Expanded(child: confirm),
              ],
            ),
    );
  }
}
