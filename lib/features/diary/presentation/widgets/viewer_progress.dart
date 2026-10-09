import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/platform/player_state.dart';
import 'package:one_second_diary/features/diary/presentation/shown_clip_playback.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hit_slop.dart';
import 'package:one_second_diary/shared/widgets/progress/viewer_progress_bar.dart';

/// The viewer's progress bar under the video: how far the clip shown has
/// played.
///
/// The player reports its position only now and then, so while it plays a
/// ticker moves the bar on each frame from the last position it reported
/// (smooth on a one-second clip); paused, nothing ticks. A report that
/// brings no new position (the player saying again that it plays) leaves
/// the bar where it is, and one a little behind the bar never pulls it
/// back; only a real move back (a replay) does. Another clip starts it
/// from 0 without animating. Only the bar repaints.
///
/// It can't be scrubbed (clips last a second or two): a tap on it, or just
/// under it, plays the clip again from the start. Screen readers play and
/// pause with the video itself.
class ViewerProgress extends StatefulWidget {
  const ViewerProgress({super.key, required this.playback});

  final ShownClipPlayback playback;

  @override
  State<ViewerProgress> createState() => _ViewerProgressState();
}

class _ViewerProgressState extends State<ViewerProgress>
    with SingleTickerProviderStateMixin {
  /// The tap reaches into the caption's top padding.
  static const double _slopBelow = 16;

  /// A report this little behind the bar is the player's lag, not a move
  /// back.
  static const Duration _lag = Duration(milliseconds: 250);

  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  /// The position the bar moves on from, and the ticker's time then.
  Duration _from = Duration.zero;
  Duration _fromAt = Duration.zero;

  /// The position the player last reported.
  Duration? _reportedPosition;

  /// The ticker's time at its last tick.
  Duration _now = Duration.zero;
  late final Ticker _ticker = createTicker((Duration elapsed) {
    _now = elapsed;
    _update();
  });

  @override
  void initState() {
    super.initState();
    widget.playback.addListener(_reported);
    _reported();
  }

  @override
  void didUpdateWidget(ViewerProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playback == widget.playback) return;
    oldWidget.playback.removeListener(_reported);
    widget.playback.addListener(_reported);
    _reported();
  }

  @override
  void dispose() {
    widget.playback.removeListener(_reported);
    _ticker.dispose();
    _progress.dispose();
    super.dispose();
  }

  /// Where the bar is, in the clip.
  Duration get _shown =>
      _from + (_ticker.isActive ? _now - _fromAt : Duration.zero);

  /// The player said how it is.
  void _reported() {
    final PlayerState? state = widget.playback.value;
    if (state == null || !state.playing) {
      // No player (another clip is coming), paused or ended: the bar is
      // where the player says.
      _ticker.stop();
      _now = Duration.zero;
      _fromAt = Duration.zero;
      _from = state?.position ?? Duration.zero;
      _reportedPosition = state?.position;
      _update();
      return;
    }
    final bool moved = state.position != _reportedPosition;
    _reportedPosition = state.position;
    if (!_ticker.isActive) {
      _from = state.position;
      _now = Duration.zero;
      _fromAt = Duration.zero;
      _ticker.start();
    } else if (moved) {
      final Duration shown = _shown;
      final bool lagging =
          state.position <= shown && shown - state.position < _lag;
      _from = lagging ? shown : state.position;
      _fromAt = _now;
    }
    _update();
  }

  void _update() {
    final PlayerState? state = widget.playback.value;
    if (state == null || state.duration <= Duration.zero) {
      _progress.value = 0;
      return;
    }
    final Duration position = state.completed ? state.duration : _shown;
    _progress.value = (position.inMicroseconds / state.duration.inMicroseconds)
        .clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) => OsdHitSlop(
    slop: const EdgeInsets.only(bottom: _slopBelow),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: () => unawaited(widget.playback.restart()),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: ViewerProgressBar(progress: _progress),
      ),
    ),
  );
}
