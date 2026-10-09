import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/shared/widgets/progress/viewer_progress_bar.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_typography.dart';
import 'package:one_second_diary/theme/osd_viewer.dart';

/// The movie player's bar (always dark): the track under the movie, filling as
/// the movie plays, with a thin notch where each chapter (each clip) starts,
/// and below it where the movie is and how long it runs, at the ends.
class MovieSeekBar extends StatefulWidget {
  const MovieSeekBar({
    super.key,
    required this.progress,
    required this.duration,
    required this.onSeek,
    this.chapters = const <MovieChapter>[],
  });

  /// The slider (its semantics).
  static const Key sliderKey = Key('movieSeekBar.slider');

  /// The track's strip (what a tap or a drag seeks along).
  static const Key trackKey = Key('movieSeekBar.track');

  /// Where the movie is ("0:30").
  static const Key positionKey = Key('movieSeekBar.position');

  /// How long it runs ("1:30").
  static const Key durationKey = Key('movieSeekBar.duration');

  /// A screen reader's step.
  static const Duration step = Duration(seconds: 10);

  /// The track's distance from the movie above.
  static const double _barTop = 12;

  /// The gap between the track and the time.
  static const double _timeGap = 8;

  /// How far the movie has played, 0 to 1.
  final ValueListenable<double> progress;

  /// How long it runs; zero until the player knows.
  final Duration duration;

  /// Seeks to a fraction (0 to 1) of the movie.
  final ValueChanged<double> onSeek;

  /// The movie's chapters, a notch at the start of each but the first;
  /// empty for a movie without.
  final List<MovieChapter> chapters;

  @override
  State<MovieSeekBar> createState() => _MovieSeekBarState();
}

class _MovieSeekBarState extends State<MovieSeekBar> {
  /// What the bar shows: the movie's progress, or the finger while dragged.
  final ValueNotifier<double> _shown = ValueNotifier<double>(0);

  /// The whole seconds played, for the time (changes once a second).
  final ValueNotifier<int> _second = ValueNotifier<int>(0);

  double? _dragged;

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onProgress);
    _onProgress();
  }

  @override
  void didUpdateWidget(MovieSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.progress, widget.progress)) {
      oldWidget.progress.removeListener(_onProgress);
      widget.progress.addListener(_onProgress);
    }
    _show(_dragged ?? widget.progress.value);
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgress);
    _shown.dispose();
    _second.dispose();
    super.dispose();
  }

  void _onProgress() {
    if (_dragged == null) _show(widget.progress.value);
  }

  void _show(double fraction) {
    final double clamped = fraction.clamp(0, 1).toDouble();
    _shown.value = clamped;
    _second.value = _at(clamped).inSeconds;
  }

  Duration _at(double fraction) => widget.duration * fraction;

  double _fractionAt(Offset local, double width) {
    final double x = Directionality.of(context) == TextDirection.rtl
        ? width - local.dx
        : local.dx;
    return width <= 0 ? 0 : (x / width).clamp(0, 1).toDouble();
  }

  void _drag(double fraction) {
    _dragged = fraction;
    _show(fraction);
  }

  void _release() {
    final double? fraction = _dragged;
    _dragged = null;
    if (fraction != null) widget.onSeek(fraction);
  }

  void _stepBy(Duration delta) {
    final Duration duration = widget.duration;
    if (duration <= Duration.zero) return;
    final Duration target = _at(_shown.value) + delta;
    widget.onSeek(
      (target.inMicroseconds / duration.inMicroseconds).clamp(0, 1).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final TextStyle time = context.typography.caption.copyWith(
      color: colors.mu,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    final Duration duration = widget.duration;
    return ValueListenableBuilder<int>(
      valueListenable: _second,
      builder: (BuildContext context, int second, Widget? strip) {
        final Duration at = Duration(seconds: second);
        return Semantics(
          key: MovieSeekBar.sliderKey,
          slider: true,
          label: Strings.moviePlayerSeek,
          value: MovieLabels.clock(at),
          increasedValue: MovieLabels.clock(
            at + MovieSeekBar.step > duration
                ? duration
                : at + MovieSeekBar.step,
          ),
          decreasedValue: MovieLabels.clock(
            at < MovieSeekBar.step ? Duration.zero : at - MovieSeekBar.step,
          ),
          onIncrease: () => _stepBy(MovieSeekBar.step),
          onDecrease: () => _stepBy(-MovieSeekBar.step),
          child: strip,
        );
      },
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            GestureDetector(
              key: MovieSeekBar.trackKey,
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTapUp: (TapUpDetails details) => widget.onSeek(
                _fractionAt(details.localPosition, constraints.maxWidth),
              ),
              onHorizontalDragStart: (DragStartDetails details) => _drag(
                _fractionAt(details.localPosition, constraints.maxWidth),
              ),
              onHorizontalDragUpdate: (DragUpdateDetails details) => _drag(
                _fractionAt(details.localPosition, constraints.maxWidth),
              ),
              onHorizontalDragEnd: (_) => _release(),
              onHorizontalDragCancel: _release,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: OsdSizes.minTap),
                child: Padding(
                  padding: const EdgeInsets.only(top: MovieSeekBar._barTop),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: MovieSeekBar._timeGap,
                    children: <Widget>[
                      _Track(
                        progress: _shown,
                        duration: duration,
                        chapters: widget.chapters,
                      ),
                      ExcludeSemantics(
                        child: Row(
                          children: <Widget>[
                            ValueListenableBuilder<int>(
                              valueListenable: _second,
                              builder: (BuildContext context, int second, _) =>
                                  Text(
                                    MovieLabels.clock(
                                      Duration(seconds: second),
                                    ),
                                    key: MovieSeekBar.positionKey,
                                    style: time,
                                  ),
                            ),
                            const Spacer(),
                            Text(
                              MovieLabels.clock(duration),
                              key: MovieSeekBar.durationKey,
                              style: time,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

/// The track with its fill, and the chapter notches over both.
class _Track extends StatelessWidget {
  const _Track({
    required this.progress,
    required this.duration,
    required this.chapters,
  });

  final ValueListenable<double> progress;
  final Duration duration;
  final List<MovieChapter> chapters;

  @override
  Widget build(BuildContext context) {
    final Widget bar = ViewerProgressBar(progress: progress);
    if (chapters.length < 2 || duration <= Duration.zero) return bar;
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        bar,
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _ChapterTicks(
                  chapters: chapters,
                  durationMs: duration.inMilliseconds,
                  textDirection: Directionality.of(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A notch the height of the track at the start of every chapter but the first,
/// in the black behind the bar, so it reads as a gap over the fill and over the
/// track alike.
class _ChapterTicks extends CustomPainter {
  const _ChapterTicks({
    required this.chapters,
    required this.durationMs,
    required this.textDirection,
  });

  final List<MovieChapter> chapters;
  final int durationMs;
  final TextDirection textDirection;

  static const double _width = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = OsdViewer.background.withValues(alpha: .8);
    for (final MovieChapter chapter in chapters.skip(1)) {
      final double fraction = (chapter.startMs / durationMs).clamp(0, 1);
      final double x = textDirection == TextDirection.rtl
          ? size.width * (1 - fraction)
          : size.width * fraction;
      canvas.drawRect(
        Rect.fromLTWH(x - _width / 2, 0, _width, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ChapterTicks oldDelegate) =>
      !listEquals(oldDelegate.chapters, chapters) ||
      oldDelegate.durationMs != durationMs ||
      oldDelegate.textDirection != textDirection;
}
