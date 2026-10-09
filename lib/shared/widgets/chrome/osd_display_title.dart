import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The big title row of a shell tab: one line that scales down to fit, with
/// an optional [trailing]. Shell tab titles are not app bars.
class OsdDisplayTitle extends StatelessWidget {
  const OsdDisplayTitle({
    super.key,
    required this.title,
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 14),
    this.trailing,
  });

  static const Key textKey = Key('osdDisplayTitle.text');

  final String title;

  final EdgeInsetsGeometry padding;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Padding(
      padding: padding,
      child: Row(
        spacing: 12,
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  title,
                  key: textKey,
                  maxLines: 1,
                  textScaler: OsdTextScale.scalerFor(
                    context,
                    OsdTextScaleRole.display,
                  ),
                  style: context.typography.title30.copyWith(
                    color: context.colors.tx,
                  ),
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
