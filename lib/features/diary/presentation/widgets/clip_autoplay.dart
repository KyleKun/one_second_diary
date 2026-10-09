import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_playback.dart';

/// Makes sure a clip that should play on its own does, once it can be
/// seen: put it in a `ClipPlayerView`'s overlay, around the controls.
///
/// `ClipPlayerView` plays on its own when its player is ready, but not
/// while its `TickerMode` is off, and a clip the Diary or the viewer shows
/// is often ready then: in a hero flight both ends are held with tickers
/// off (the viewer opening, the Diary coming back on the day it showed
/// last). This plays the clip once its ticker is back, if it has not
/// played yet. A clip that has played (or that the user paused since) is
/// left alone.
class ClipAutoplay extends StatefulWidget {
  const ClipAutoplay({
    super.key,
    required this.enabled,
    required this.playback,
    required this.controls,
    required this.child,
  });

  /// Whether the clip should play on its own.
  final bool enabled;

  final ClipPlayback playback;
  final ClipPlayerControls controls;
  final Widget child;

  @override
  State<ClipAutoplay> createState() => _ClipAutoplayState();
}

class _ClipAutoplayState extends State<ClipAutoplay> {
  /// It played, or was started: never again.
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _check();
  }

  @override
  void didUpdateWidget(ClipAutoplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _check();
  }

  void _check() {
    if (_done || !widget.enabled) return;
    switch (widget.playback.phase) {
      case ClipPlaybackPhase.playing ||
          ClipPlaybackPhase.completed ||
          ClipPlaybackPhase.failed:
        _done = true;
      case ClipPlaybackPhase.paused when TickerMode.valuesOf(context).enabled:
        _done = true;
        // After the frame: playing reports back to the overlay building now.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.controls.play().ignore();
        });
      case ClipPlaybackPhase.paused || ClipPlaybackPhase.loading:
        return;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
