import 'package:flutter/widgets.dart';

/// Builds [builder] with [value], but holds the last value shown while its
/// page is hidden (`TickerMode` off: another tab is on screen, or a page
/// is pushed over the tabs), and shows the latest once it is visible
/// again.
///
/// Animations don't run while hidden (their time still passes), so a
/// change made meanwhile (a clip saved from the camera, a profile switched
/// in Settings) would otherwise be over before the user sees Today. Held,
/// it plays in front of them, once.
class HeldWhileHidden<T> extends StatefulWidget {
  const HeldWhileHidden({
    super.key,
    required this.value,
    required this.builder,
  });

  /// The latest value.
  final T value;

  final Widget Function(BuildContext context, T value) builder;

  @override
  State<HeldWhileHidden<T>> createState() => _HeldWhileHiddenState<T>();
}

class _HeldWhileHiddenState<T> extends State<HeldWhileHidden<T>> {
  late T _shown = widget.value;
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    if (_visible) _shown = widget.value;
  }

  @override
  void didUpdateWidget(HeldWhileHidden<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_visible) _shown = widget.value;
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _shown);
}
