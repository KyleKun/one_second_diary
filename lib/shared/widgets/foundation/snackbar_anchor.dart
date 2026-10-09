import 'package:flutter/widgets.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';

/// Marks the widget a floating snackbar sits above, with the [gap] between
/// them (`OsdSpace.snackbar*`).
///
/// It registers with the nearest `OsdSnackbarHost`. When several anchors are
/// live, the snackbar sits above the highest one; anchors in an inactive tab
/// (`TickerMode` off) are ignored. With no anchor the snackbar sits just above
/// the bottom inset. A snackbar already up follows its anchor when the anchor
/// moves, resizes or changes its [gap] (the host re-measures after each
/// frame while it shows).
class SnackbarAnchor extends StatefulWidget {
  const SnackbarAnchor({super.key, required this.gap, required this.child});

  /// The space between the anchor's top and the snackbar.
  final double gap;

  final Widget child;

  @override
  State<SnackbarAnchor> createState() => SnackbarAnchorState();
}

/// The state of a [SnackbarAnchor], which the host measures.
class SnackbarAnchorState extends State<SnackbarAnchor> {
  OsdSnackbarHostState? _host;
  bool _active = true;

  double get gap => widget.gap;

  /// Whether the anchor is on screen (its tab is active).
  bool get isActive => mounted && _active;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _active = TickerMode.valuesOf(context).enabled;
    final host = OsdSnackbarHost.maybeOf(context);
    if (!identical(host, _host)) {
      _host?.detachAnchor(this);
      _host = host?..attachAnchor(this);
    }
  }

  @override
  void dispose() {
    _host?.detachAnchor(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
