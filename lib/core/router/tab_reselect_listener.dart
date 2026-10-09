import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/tab_reselect_scope.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Hears the user tap [tab] in the nav while it is already shown (the
/// shell also pops the tab back to its first page): [scrollController]
/// scrolls back to its start (300 ms, a jump under reduced motion), then
/// [onReselect] runs (Today back to its first clip, the Diary back to this
/// month).
///
/// Put it around a tab's root page. Outside the shell it hears nothing.
class TabReselectListener extends StatefulWidget {
  const TabReselectListener({
    super.key,
    required this.tab,
    this.scrollController,
    this.onReselect,
    required this.child,
  });

  /// The tab this page is the root of.
  final AppRoute tab;

  /// The page's main scroll view.
  final ScrollController? scrollController;

  final VoidCallback? onReselect;

  final Widget child;

  @override
  State<TabReselectListener> createState() => _TabReselectListenerState();
}

class _TabReselectListenerState extends State<TabReselectListener> {
  TabReselects? _reselects;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final TabReselects? reselects = TabReselectScope.maybeOf(context);
    if (identical(reselects, _reselects)) return;
    _reselects?.removeListener(_heard);
    _reselects = reselects?..addListener(_heard);
  }

  @override
  void dispose() {
    _reselects?.removeListener(_heard);
    super.dispose();
  }

  void _heard() {
    if (_reselects?.last != widget.tab) return;
    final ScrollController? scroll = widget.scrollController;
    if (scroll != null && scroll.hasClients && scroll.offset > 0) {
      if (OsdMotion.reduced(context)) {
        scroll.jumpTo(0);
      } else {
        unawaited(
          scroll.animateTo(
            0,
            duration: OsdMotion.emphasized,
            curve: OsdMotion.standardCurve,
          ),
        );
      }
    }
    widget.onReselect?.call();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
