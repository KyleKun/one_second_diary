import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// A page body whose [content] scrolls above a pinned [footer]: while the
/// content runs on under the footer, a line tops the footer, fading in and out.
class ScrollUnderFooter extends StatefulWidget {
  const ScrollUnderFooter({
    super.key,
    required this.content,
    required this.footer,
  });

  static const Key lineKey = Key('scrollUnderFooter.line');

  /// The scroll view.
  final Widget content;

  final Widget footer;

  @override
  State<ScrollUnderFooter> createState() => _ScrollUnderFooterState();
}

class _ScrollUnderFooterState extends State<ScrollUnderFooter> {
  bool _under = false;

  bool _follow(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return false;
    final bool under = metrics.extentAfter > 0;
    if (under != _under) setState(() => _under = under);
    return false;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Expanded(
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (ScrollMetricsNotification notification) =>
              notification.depth == 0 && _follow(notification.metrics),
          child: NotificationListener<ScrollUpdateNotification>(
            onNotification: (ScrollUpdateNotification notification) =>
                notification.depth == 0 && _follow(notification.metrics),
            child: widget.content,
          ),
        ),
      ),
      Stack(
        children: <Widget>[
          widget.footer,
          PositionedDirectional(
            start: 0,
            end: 0,
            top: 0,
            child: AnimatedOpacity(
              key: ScrollUnderFooter.lineKey,
              opacity: _under ? 1 : 0,
              duration: OsdMotion.d(context, OsdMotion.fast),
              curve: OsdMotion.fastCurve,
              child: SizedBox(
                height: 1,
                child: ColoredBox(color: context.colors.ln),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
