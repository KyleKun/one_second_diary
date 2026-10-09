import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Shows a loading visual only once [loading] has lasted [delay], so quick
/// work never flashes a spinner.
///
/// [builder] gets `showLoading`: false until the delay has passed, and false
/// again as soon as [loading] ends.
class OsdLoadingDelay extends StatefulWidget {
  const OsdLoadingDelay({
    super.key,
    required this.loading,
    required this.builder,
    this.delay = OsdMotion.loadingDelay,
  });

  final bool loading;

  /// Builds the content, with or without the loading visual.
  final Widget Function(BuildContext context, bool showLoading) builder;

  final Duration delay;

  @override
  State<OsdLoadingDelay> createState() => _OsdLoadingDelayState();
}

class _OsdLoadingDelayState extends State<OsdLoadingDelay> {
  Timer? _timer;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(OsdLoadingDelay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading != widget.loading) _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (!widget.loading) {
      _show = false;
      return;
    }
    if (widget.delay == Duration.zero) {
      _show = true;
      return;
    }
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.loading && _show);
}
