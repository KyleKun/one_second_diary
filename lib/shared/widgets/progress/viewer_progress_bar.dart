import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_viewer.dart';

/// The playback bar of the full-screen viewer (always dark). It follows
/// [progress] (a ticker driven by the player) without rebuilding its parent,
/// linearly, and can't be scrubbed. Decorative.
class ViewerProgressBar extends StatelessWidget {
  const ViewerProgressBar({super.key, required this.progress});

  static const Key trackKey = Key('viewerProgressBar.track');

  static const Key fillKey = Key('viewerProgressBar.fill');

  /// Playback progress, 0 to 1.
  final ValueListenable<double> progress;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(2);
    return ExcludeSemantics(
      child: SizedBox(
        height: 3,
        child: DecoratedBox(
          key: trackKey,
          decoration: BoxDecoration(
            color: OsdViewer.progressTrack,
            borderRadius: radius,
          ),
          child: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, value, child) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0, 1).toDouble(),
                heightFactor: 1,
                child: child,
              ),
            ),
            child: DecoratedBox(
              key: fillKey,
              decoration: BoxDecoration(
                color: OsdViewer.progressFill,
                borderRadius: radius,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
