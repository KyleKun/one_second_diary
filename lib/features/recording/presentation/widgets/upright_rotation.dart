import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/features/recording/presentation/camera_motion.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Keeps [child] upright while the phone turns: the camera's layout stays
/// portrait and its glyphs turn instead, always the short way round; at
/// once under reduced motion.
class UprightRotation extends StatefulWidget {
  const UprightRotation({
    super.key,
    required this.orientation,
    required this.child,
  });

  /// How the phone is held.
  final DeviceOrientation orientation;

  final Widget child;

  /// The quarter turns that keep a glyph upright in [orientation].
  static int quarterTurnsOf(DeviceOrientation orientation) =>
      switch (orientation) {
        DeviceOrientation.portraitUp => 0,
        DeviceOrientation.landscapeLeft => 1,
        DeviceOrientation.portraitDown => 2,
        DeviceOrientation.landscapeRight => -1,
      };

  @override
  State<UprightRotation> createState() => _UprightRotationState();
}

class _UprightRotationState extends State<UprightRotation> {
  late double _turns = UprightRotation.quarterTurnsOf(widget.orientation) / 4;

  @override
  void didUpdateWidget(UprightRotation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orientation == widget.orientation) return;
    final double target =
        UprightRotation.quarterTurnsOf(widget.orientation) / 4;
    // The difference in (−½, ½]: never the long way round.
    double delta = (target - _turns) % 1;
    if (delta > .5) delta -= 1;
    _turns += delta;
  }

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: _turns,
    duration: OsdMotion.reduced(context)
        ? Duration.zero
        : CameraMotion.glyphTurn,
    curve: OsdMotion.standardCurve,
    child: widget.child,
  );
}
