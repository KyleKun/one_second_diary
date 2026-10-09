import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/platform/player_handle.dart';
import 'package:one_second_diary/core/platform/player_state.dart';
import 'package:one_second_diary/features/clip_editor/data/filmstrip_frames.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length_format.dart';
import 'package:one_second_diary/features/clip_editor/domain/trim_selection.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/data/shown_player.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_skeleton_block.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// The filmstrip with the trim window.
///
/// - A source of up to [viewSpanMs] spans the strip; a longer one shows
///   that much at a time. Dragged away from the window it pans under the
///   window, which keeps its place on screen and so moves through the
///   source; a window held near an end of the strip scrolls the view on.
///   The window never leaves the screen.
/// - Drag the window to move it, an edge to resize it; the parent applies
///   the rules (`TrimSelection`). A new window from elsewhere (a quick cut)
///   slides into place; a dragged one follows the finger.
/// - A line marks where the preview is while it plays, from the source's
///   player in the screen's `PlayerPool`.
/// - Frames are asked for after the frame that needs them is built: the
///   tiles in view first, then those within one view on either side (never
///   the whole of a long source; a pan asks again), none while the clip
///   saves. Only the tiles in view are built. Media stays left to right in
///   RTL.
/// - For a screen reader it is a slider: increase and decrease move the
///   window, and the "longer" and "shorter" actions move its end (the
///   length a drag sets, without dragging).
class FilmstripTrimmer extends StatefulWidget {
  const FilmstripTrimmer({
    super.key,
    required this.sourcePath,
    required this.trim,
    required this.aspectRatio,
    required this.trimming,
    required this.saving,
    required this.onTrimStarted,
    required this.onMoved,
    required this.onStartDragged,
    required this.onEndDragged,
    required this.onTrimEnded,
  });

  static const Key stripKey = Key('filmstripTrimmer.strip');

  /// The masks and the window, painted over the frames.
  static const Key windowKey = Key('filmstripTrimmer.window');

  /// The strip's height.
  static const double height = 50;

  /// The most of the source the strip shows at once; a longer source pans.
  static const int viewSpanMs = 12000;

  /// Frame tile [index], once it is made.
  static Key frameKey(int index) =>
      ValueKey<String>('filmstripTrimmer.frame.$index');

  final String sourcePath;
  final TrimSelection trim;

  /// The source video's width / height: a frame tile is about 50 × 50·ratio.
  final double aspectRatio;

  /// A finger is on the window.
  final bool trimming;

  /// The clip is being saved: no frame is made meanwhile (the render
  /// decodes the same file).
  final bool saving;

  final VoidCallback onTrimStarted;
  final ValueChanged<int> onMoved;
  final ValueChanged<int> onStartDragged;
  final ValueChanged<int> onEndDragged;
  final VoidCallback onTrimEnded;

  @override
  State<FilmstripTrimmer> createState() => _FilmstripTrimmerState();
}

/// What a drag holds: an edge, the window, or the strip itself (a long
/// source pans).
enum _Grip { start, end, window, strip }

/// A window as fractions of the part of the source in view.
typedef _Fractions = ({double start, double length});

class _FilmstripTrimmerState extends State<FilmstripTrimmer>
    with TickerProviderStateMixin {
  /// Reach of an edge grip outside the window.
  static const double _edgeOutside = 22;

  /// Reach of an edge grip inside the window.
  static const double _edgeInside = 16;

  /// How far increase and decrease move the window.
  static const int _semanticsStepMs = 100;

  /// How far "longer" and "shorter" move the end: any length a drag
  /// reaches, without dragging (WCAG 2.2 SC 2.5.7).
  static const int _lengthStepMs = 500;

  static const double _gutter = OsdSpace.pageGutter;

  late final FilmstripFrames _frameMaker = context.read<FilmstripFrames>();
  late final PlayerPool _pool = context.read<PlayerPool>();

  /// Where the view starts in the source.
  late int _viewStartMs = _viewShowing(widget.trim, from: 0);

  /// How much of the source the strip shows.
  int get _viewMs =>
      math.min(widget.trim.sourceMs, FilmstripTrimmer.viewSpanMs);

  /// Whether the source is longer than the view, so the strip pans.
  bool get _pans => widget.trim.sourceMs > FilmstripTrimmer.viewSpanMs;

  double get _stripWidth => context.size!.width - 2 * _gutter;

  /// The view start, from [from], that shows all of [trim]'s window.
  int _viewShowing(TrimSelection trim, {required int from}) {
    final int span = math.min(trim.sourceMs, FilmstripTrimmer.viewSpanMs);
    int start = from;
    if (trim.startMs < start) start = trim.startMs;
    if (trim.endMs > start + span) start = trim.endMs - span;
    return start.clamp(0, trim.sourceMs - span);
  }

  _Fractions _fractionsOf(TrimSelection trim) => (
    start: (trim.startMs - _viewStartMs) / _viewMs,
    length: trim.lengthMs / _viewMs,
  );

  /// A new window slides into place (a quick cut); a dragged one follows
  /// the finger.
  late final AnimationController _slide = AnimationController(
    vsync: this,
    value: 1,
  );
  late final CurvedAnimation _slideCurve = CurvedAnimation(
    parent: _slide,
    curve: OsdMotion.standardCurve,
  );
  late final AnimationController _glow = AnimationController(
    vsync: this,
    value: widget.trimming ? 1 : 0,
  );
  late _Fractions _from = _fractionsOf(widget.trim);
  late _Fractions _to = _from;
  late TrimWindowPainter _painter = _makePainter();

  TrimWindowPainter _makePainter() => TrimWindowPainter(
    from: _from,
    to: _to,
    sourceEnd: (widget.trim.sourceMs - _viewStartMs) / _viewMs,
    slide: _slideCurve,
    glow: _glow,
    playhead: _playhead,
  );

  /// The window as painted now, as fractions of the view.
  _Fractions _paintedFractions() {
    final double t = _slideCurve.value;
    return (
      start: lerpDouble(_from.start, _to.start, t)!,
      length: lerpDouble(_from.length, _to.length, t)!,
    );
  }

  /// Puts the window where [widget.trim] is at once.
  void _jump() {
    _from = _to = _fractionsOf(widget.trim);
    _slide.value = 1;
    _painter = _makePainter();
  }

  /// The player of the source, once the pool shows it.
  PlayerHandle? _player;

  /// Where the playing preview is, as a fraction of the view.
  final ValueNotifier<double?> _playhead = ValueNotifier<double?>(null);

  /// Follows the pool's player while it shows this source.
  void _onShown() {
    final ShownPlayer? shown = _pool.shown.value;
    final PlayerHandle? player = shown?.path == widget.sourcePath
        ? shown?.handle
        : null;
    if (identical(player, _player)) return;
    _player?.value.removeListener(_onPlayer);
    _player = player?..value.addListener(_onPlayer);
    _onPlayer();
  }

  /// The player reports its position every 100 ms; between reports the
  /// playhead moves on with the frame clock, never more than
  /// [_glideLimit] past the last report.
  late final Ticker _glide = createTicker(_onGlide);
  static const Duration _glideLimit = Duration(milliseconds: 200);

  /// The last position reported, and when (on [_glide]'s clock).
  Duration _reported = Duration.zero;
  Duration _reportedAt = Duration.zero;
  Duration _glideNow = Duration.zero;

  void _onPlayer() {
    final PlayerState? state = _player?.value.value;
    if (state == null || !state.playing) {
      if (_glide.isActive) _glide.stop();
      _playhead.value = null;
      return;
    }
    if (!_glide.isActive) {
      _glideNow = Duration.zero;
      unawaited(_glide.start());
    }
    _reported = state.position;
    _reportedAt = _glideNow;
    _showPlayhead(state.position);
  }

  void _onGlide(Duration elapsed) {
    _glideNow = elapsed;
    final Duration since = elapsed - _reportedAt;
    _showPlayhead(_reported + (since < _glideLimit ? since : _glideLimit));
  }

  void _showPlayhead(Duration position) =>
      _playhead.value = (position.inMilliseconds - _viewStartMs) / _viewMs;

  StreamSubscription<FilmstripFrame>? _frameStream;

  /// The tiles asked for last.
  _Frames? _asked;

  /// The frames made so far, by tile.
  final Map<int, String> _frames = <int, String>{};

  /// The tile grid of the whole source at [stripWidth]: about 50 ×
  /// 50·ratio each, spread evenly over the source, made at the screen's
  /// density; a source of 10 s or more gets a tile a second
  /// (`FilmstripFrames.tileCount`). Only the tiles near the view are made
  /// ([_wantedOrder]).
  _Frames _framesFor(double stripWidth, double pixelRatio) {
    final double ratio = widget.aspectRatio;
    final int height = (FilmstripTrimmer.height * pixelRatio).round();
    final double sourceWidth = stripWidth * widget.trim.sourceMs / _viewMs;
    return (
      path: widget.sourcePath,
      durationMs: widget.trim.sourceMs,
      count: FilmstripFrames.tileCount(
        durationMs: widget.trim.sourceMs,
        fitted: (sourceWidth / (FilmstripTrimmer.height * ratio)).ceil(),
      ),
      width: (height * ratio).round(),
      height: height,
    );
  }

  /// The tiles of [frames] that cover [fromMs] to [toMs] of the source.
  static ({int first, int last}) _tilesOver(
    _Frames frames, {
    required int fromMs,
    required int toMs,
  }) {
    final double tileMs = frames.durationMs / frames.count;
    return (
      first: (fromMs / tileMs).floor().clamp(0, frames.count - 1),
      last: (toMs / tileMs).ceil().clamp(1, frames.count) - 1,
    );
  }

  /// The tiles in view, first to last.
  ({int first, int last}) _tilesInView(_Frames frames) =>
      _tilesOver(frames, fromMs: _viewStartMs, toMs: _viewStartMs + _viewMs);

  /// The tiles not made yet that are wanted: those in view first, then
  /// those within one view after it, then within one view before it.
  List<int> _wantedOrder(_Frames frames) {
    final ({int first, int last}) view = _tilesInView(frames);
    final ({int first, int last}) near = _tilesOver(
      frames,
      fromMs: _viewStartMs - _viewMs,
      toMs: _viewStartMs + 2 * _viewMs,
    );
    return <int>[
      for (int tile = view.first; tile <= view.last; tile++) tile,
      for (int tile = view.last + 1; tile <= near.last; tile++) tile,
      for (int tile = view.first - 1; tile >= near.first; tile--) tile,
    ].where((int tile) => !_frames.containsKey(tile)).toList();
  }

  /// Asks for [frames] after this frame when they are not the ones asked
  /// for already: nothing is made while a frame is built.
  void _want(_Frames frames) {
    if (frames == _asked) return;
    _asked = frames;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || frames != _asked) return;
      setState(_frames.clear);
      _request(frames);
    });
  }

  /// Asks again, keeping the frames made, so the tiles now in view come
  /// first and those near the new view get made (after a pan, or a save).
  void _reorder() {
    final _Frames? frames = _asked;
    if (frames == null || widget.saving) return;
    final List<int> wanted = _wantedOrder(frames);
    if (wanted.isEmpty) return;
    final ({int first, int last}) view = _tilesInView(frames);
    final bool missingInView = wanted.any(
      (int tile) => tile >= view.first && tile <= view.last,
    );
    if (missingInView || _frameStream == null) _request(frames);
  }

  void _request(_Frames frames) {
    unawaited(_frameStream?.cancel());
    _frameStream = null;
    if (widget.saving) return;
    final List<int> order = _wantedOrder(frames);
    if (order.isEmpty) return;
    late final StreamSubscription<FilmstripFrame> stream;
    stream = _frameMaker
        .of(
          frames.path,
          durationMs: frames.durationMs,
          count: frames.count,
          width: frames.width,
          height: frames.height,
          order: order,
        )
        .listen(
          (FilmstripFrame frame) =>
              setState(() => _frames[frame.index] = frame.path),
          onDone: () {
            if (identical(_frameStream, stream)) _frameStream = null;
          },
        );
    _frameStream = stream;
  }

  @override
  void initState() {
    super.initState();
    _pool.shown.addListener(_onShown);
    _onShown();
  }

  @override
  void didUpdateWidget(FilmstripTrimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trimming && oldWidget.trimming) {
      _playHaptics(oldWidget.trim, widget.trim);
    }
    if (widget.trimming != oldWidget.trimming) {
      unawaited(
        _glow.animateTo(
          widget.trimming ? 1 : 0,
          duration: OsdMotion.d(context, OsdMotion.fast),
          curve: OsdMotion.fastCurve,
        ),
      );
    }
    if (widget.saving != oldWidget.saving) {
      if (widget.saving) {
        unawaited(_frameStream?.cancel());
        _frameStream = null;
      } else {
        _reorder();
      }
    }
    if (widget.trim != oldWidget.trim) {
      final int view = _viewShowing(widget.trim, from: _viewStartMs);
      final bool slides =
          _grip == null && !widget.trimming && view == _viewStartMs;
      final bool viewMoved = view != _viewStartMs;
      _viewStartMs = view;
      // Brought into view from elsewhere (a quick cut, a screen reader):
      // the frames near the new view come first.
      if (viewMoved && _grip == null) _reorder();
      if (!slides) {
        _jump();
        return;
      }
      _from = _paintedFractions();
      _to = _fractionsOf(widget.trim);
      _painter = _makePainter();
      _slide.duration = OsdMotion.d(context, OsdMotion.standard);
      unawaited(_slide.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _pool.shown.removeListener(_onShown);
    _player?.value.removeListener(_onPlayer);
    _glide.dispose();
    _edgeScroll.dispose();
    _playhead.dispose();
    unawaited(_frameStream?.cancel());
    _slideCurve.dispose();
    _slide.dispose();
    _glow.dispose();
    super.dispose();
  }

  /// While a finger is on the window: a click when an edge snaps to a
  /// quick cut, a light tap when the window meets an end of the source.
  void _playHaptics(TrimSelection from, TrimSelection to) {
    final int? cut = to.quickCutMs;
    if (cut != null && cut != from.quickCutMs) {
      unawaited(OsdHaptic.selection.play());
    } else if (_atAnEnd(to) && !_atAnEnd(from)) {
      unawaited(OsdHaptic.light.play());
    }
  }

  static bool _atAnEnd(TrimSelection trim) =>
      trim.startMs == 0 || trim.endMs == trim.sourceMs;

  _Grip? _grip;
  late double _dragStartX;
  late TrimSelection _dragFrom;
  late int _dragFromViewMs;

  /// What a finger at [x] px into the strip holds, if anything.
  _Grip? _gripAt(double x) {
    final TrimSelection trim = widget.trim;
    if (trim.locked) return null;
    final Rect window = _painter.windowRect(
      Size(_stripWidth, FilmstripTrimmer.height),
    );
    final double inside = math.min(_edgeInside, window.width / 4);
    if (x >= window.left - _edgeOutside && x <= window.left + inside) {
      return _Grip.start;
    }
    if (x >= window.right - inside && x <= window.right + _edgeOutside) {
      return _Grip.end;
    }
    if (x > window.left && x < window.right) return _Grip.window;
    return _pans ? _Grip.strip : null;
  }

  void _onDragStart(DragStartDetails details) {
    final double x = details.localPosition.dx - _gutter;
    final _Grip? grip = _gripAt(x);
    _grip = grip;
    if (grip == null) return;
    _dragStartX = _fingerX = x;
    _dragFrom = widget.trim;
    _dragFromViewMs = _viewStartMs;
    widget.onTrimStarted();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final _Grip? grip = _grip;
    if (grip == null) return;
    _fingerX = details.localPosition.dx - _gutter;
    _follow(grip);
    if (grip == _Grip.window && _pans) _scrollAtTheEdges();
  }

  /// Moves what [grip] holds to where the finger is now, over the view as
  /// it is now.
  void _follow(_Grip grip) {
    final int ms = ((_fingerX - _dragStartX) * _viewMs / _stripWidth).round();
    final int viewEnd = _viewStartMs + _viewMs;
    switch (grip) {
      case _Grip.strip:
        // The strip pans under the window, which keeps its place on screen:
        // the selection moves with the strip. A playing preview's playhead
        // follows on the next frame.
        final int view = (_dragFromViewMs - ms).clamp(
          0,
          widget.trim.sourceMs - _viewMs,
        );
        _scrollTo(view);
        widget.onMoved(view + _dragFrom.startMs - _dragFromViewMs);
      case _Grip.window:
        // The view may have scrolled on under the finger since the drag
        // began ([_scrollAtTheEdges]).
        final int scrolled = _viewStartMs - _dragFromViewMs;
        widget.onMoved(
          (_dragFrom.startMs + ms + scrolled).clamp(
            _viewStartMs,
            viewEnd - _dragFrom.lengthMs,
          ),
        );
      case _Grip.start:
        widget.onStartDragged(math.max(_viewStartMs, _dragFrom.startMs + ms));
      case _Grip.end:
        widget.onEndDragged(math.min(viewEnd, _dragFrom.endMs + ms));
    }
  }

  void _onDragEnd() {
    final _Grip? grip = _grip;
    if (grip == null) return;
    _grip = null;
    if (_edgeScroll.isActive) _edgeScroll.stop();
    widget.onTrimEnded();
    if (_viewStartMs != _dragFromViewMs) _reorder();
  }

  /// Where the finger is, in px into the strip, while it drags.
  double _fingerX = 0;

  /// How near the strip's ends a dragged window scrolls the view on.
  static const double _edgeScrollZone = 24;

  /// How fast the view scrolls with the finger at (or past) an end: a
  /// view a second, slower nearer the zone's inner side.
  static const int _edgeScrollMsPerSecond = FilmstripTrimmer.viewSpanMs;

  /// While a dragged window is held near an end of the strip, the view
  /// scrolls on and the window with it, so any second of a long source is
  /// one drag away.
  late final Ticker _edgeScroll = createTicker(_onEdgeScroll);
  Duration _edgeScrolledAt = Duration.zero;

  /// How hard the finger pushes against an end: 0 away from them, up to 1
  /// at or past the right end, down to -1 at or past the left one; only
  /// towards the end the finger has moved to since the drag began.
  double get _edgePush {
    final double width = _stripWidth;
    final double right = (_fingerX - width + _edgeScrollZone) / _edgeScrollZone;
    final double left = (_edgeScrollZone - _fingerX) / _edgeScrollZone;
    if (right > 0 && _fingerX > _dragStartX) return math.min(right, 1.0);
    if (left > 0 && _fingerX < _dragStartX) return -math.min(left, 1.0);
    return 0;
  }

  void _scrollAtTheEdges() {
    if (_edgePush == 0) {
      if (_edgeScroll.isActive) _edgeScroll.stop();
      return;
    }
    if (_edgeScroll.isActive) return;
    _edgeScrolledAt = Duration.zero;
    unawaited(_edgeScroll.start());
  }

  void _onEdgeScroll(Duration elapsed) {
    final Duration since = elapsed - _edgeScrolledAt;
    _edgeScrolledAt = elapsed;
    final double push = _edgePush;
    if (_grip != _Grip.window || push == 0) {
      _edgeScroll.stop();
      return;
    }
    final int step =
        (push * _edgeScrollMsPerSecond * since.inMicroseconds / 1e6).round();
    final int view = (_viewStartMs + step).clamp(
      0,
      widget.trim.sourceMs - _viewMs,
    );
    if (view == _viewStartMs) return;
    _scrollTo(view);
    _follow(_Grip.window);
  }

  /// Shows the source from [view] on, the window staying where it is on
  /// screen: the drag that scrolls moves the selection along with it.
  void _scrollTo(int view) => setState(() {
    _viewStartMs = view;
    _painter = _makePainter();
  });

  @override
  Widget build(BuildContext context) {
    final TrimSelection trim = widget.trim;
    final ClipLengthFormat format = ClipLengthFormat.of(
      Localizations.localeOf(context).toString(),
    );
    String valueOf(TrimSelection trim) => Strings.saveVideoTrimValueSemantics(
      start: format.seconds(trim.startMs),
      length: format.seconds(trim.lengthMs),
    );
    final TrimSelection later = trim.movedTo(trim.startMs + _semanticsStepMs);
    final TrimSelection earlier = trim.movedTo(trim.startMs - _semanticsStepMs);
    final TrimSelection longer = trim.withEndAt(trim.endMs + _lengthStepMs);
    final TrimSelection shorter = trim.withEndAt(trim.endMs - _lengthStepMs);
    return Semantics(
      container: true,
      slider: true,
      label: Strings.saveVideoTrimSemantics,
      value: valueOf(trim),
      increasedValue: trim.locked ? null : valueOf(later),
      decreasedValue: trim.locked ? null : valueOf(earlier),
      onIncrease: trim.locked ? null : () => widget.onMoved(later.startMs),
      onDecrease: trim.locked ? null : () => widget.onMoved(earlier.startMs),
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        if (longer != trim)
          CustomSemanticsAction(label: Strings.saveVideoTrimLonger): () =>
              widget.onEndDragged(trim.endMs + _lengthStepMs),
        if (shorter != trim)
          CustomSemanticsAction(label: Strings.saveVideoTrimShorter): () =>
              widget.onEndDragged(trim.endMs - _lengthStepMs),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: (_) => _onDragEnd(),
        onHorizontalDragCancel: _onDragEnd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _gutter),
          child: SizedBox(
            key: FilmstripTrimmer.stripKey,
            height: FilmstripTrimmer.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(OsdRadius.r10),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double stripWidth = constraints.maxWidth;
                  final _Frames frames = _framesFor(
                    stripWidth,
                    MediaQuery.devicePixelRatioOf(context),
                  );
                  _want(frames);
                  final ({int first, int last}) view = _tilesInView(frames);
                  final double pxPerMs = stripWidth / _viewMs;
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _FrameLayer(
                        frames: _frames,
                        first: view.first,
                        last: view.last,
                        tileWidth: frames.durationMs / frames.count * pxPerMs,
                        offset: _viewStartMs * pxPerMs,
                        pixelHeight: frames.height,
                      ),
                      RepaintBoundary(
                        child: CustomPaint(
                          key: FilmstripTrimmer.windowKey,
                          painter: _painter,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The frames of the tiles in view, each as it comes, over a pulse while
/// one of them is still missing.
class _FrameLayer extends StatelessWidget {
  const _FrameLayer({
    required this.frames,
    required this.first,
    required this.last,
    required this.tileWidth,
    required this.offset,
    required this.pixelHeight,
  });

  /// The frames made so far, by tile.
  final Map<int, String> frames;

  /// The tiles in view.
  final int first;
  final int last;

  final double tileWidth;

  /// How far the view is into the source, in px.
  final double offset;

  /// A tile's height in physical pixels (the decode size).
  final int pixelHeight;

  @override
  Widget build(BuildContext context) {
    bool missing = false;
    for (int tile = first; tile <= last; tile++) {
      missing = missing || !frames.containsKey(tile);
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (missing)
          const OsdSkeletonBlock(
            width: double.infinity,
            height: FilmstripTrimmer.height,
            radius: OsdRadius.r10,
            effect: OsdSkeletonEffect.pulse,
          ),
        RepaintBoundary(
          child: Stack(
            children: <Widget>[
              for (int tile = first; tile <= last; tile++)
                if (frames[tile] case final String path)
                  Positioned(
                    left: tile * tileWidth - offset,
                    top: 0,
                    width: tileWidth,
                    height: FilmstripTrimmer.height,
                    child: _FrameTile(
                      key: FilmstripTrimmer.frameKey(tile),
                      path: path,
                      pixelHeight: pixelHeight,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The tile grid of the source: the strip asks for the tiles near the view.
typedef _Frames = ({
  String path,
  int durationMs,
  int count,
  int width,
  int height,
});

/// One frame of the strip, decoded at the strip's size and faded in.
class _FrameTile extends StatelessWidget {
  const _FrameTile({super.key, required this.path, required this.pixelHeight});

  final String path;

  /// The tile's height in physical pixels (the decode size).
  final int pixelHeight;

  @override
  Widget build(BuildContext context) => Image.file(
    File(path),
    fit: BoxFit.cover,
    cacheHeight: pixelHeight,
    gaplessPlayback: true,
    excludeFromSemantics: true,
    errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
        const SizedBox.shrink(),
    frameBuilder:
        (BuildContext context, Widget child, int? frame, bool synchronous) =>
            synchronous
            ? child
            : AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: OsdMotion.d(context, OsdMotion.selection),
                curve: OsdMotion.selectionCurve,
                child: child,
              ),
  );
}

/// Paints the dimmed filmstrip outside the trim window, the window's
/// border, while a finger is on it `OsdMedia.trimGlow` around it, and the
/// playhead.
///
/// Positions are fractions of the part of the source in view. The window
/// slides from [from] to [to] as [slide] runs, the glow shows as much as
/// [glow] says, and the [playhead] marks where the playing preview is; all
/// repaint without a rebuild.
class TrimWindowPainter extends CustomPainter {
  TrimWindowPainter({
    required this.from,
    required this.to,
    required this.sourceEnd,
    required this.slide,
    required this.glow,
    required this.playhead,
  }) : super(repaint: Listenable.merge(<Listenable>[slide, glow, playhead]));

  /// The window before the change.
  final ({double start, double length}) from;

  /// The window after the change.
  final ({double start, double length}) to;

  /// Where the source ends (1 when its end is in view): a window widened
  /// to [minWidth] never runs past it.
  final double sourceEnd;

  /// From [from] (0) to [to] (1).
  final Animation<double> slide;

  /// No glow (0) to the full glow (1).
  final Animation<double> glow;

  /// Where the playing preview is; null while it does not play.
  final ValueListenable<double?> playhead;

  /// A window is never drawn thinner than this.
  static const double minWidth = 20;

  static const double _border = 2.5;
  static const double _radius = OsdRadius.r8;

  static const double _playheadWidth = 2;
  static const double _playheadInset = 5;

  /// The window in a strip of [size], as painted now.
  Rect windowRect(Size size) {
    final double t = slide.value;
    final double start = lerpDouble(from.start, to.start, t)!;
    final double length = lerpDouble(from.length, to.length, t)!;
    final double width = math.min(
      size.width,
      math.max(minWidth, length * size.width),
    );
    final double left = math.min(
      start * size.width,
      sourceEnd * size.width - width,
    );
    return Rect.fromLTWH(left, 0, width, size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect window = windowRect(size);
    final Paint mask = Paint()..color = OsdMedia.filmstripMask;
    final double left = window.left.clamp(0, size.width);
    final double right = window.right.clamp(0, size.width);
    if (left > 0) {
      canvas.drawRect(Rect.fromLTRB(0, 0, left, size.height), mask);
    }
    if (right < size.width) {
      canvas.drawRect(Rect.fromLTRB(right, 0, size.width, size.height), mask);
    }
    final RRect outline = RRect.fromRectAndRadius(
      window,
      const Radius.circular(_radius),
    );
    if (glow.value > 0) {
      const BoxShadow shadow = OsdMedia.trimGlow;
      canvas.drawDRRect(
        outline.inflate(shadow.spreadRadius),
        outline,
        Paint()
          ..color = shadow.color.withValues(alpha: shadow.color.a * glow.value),
      );
    }
    canvas.drawRRect(
      outline.deflate(_border / 2),
      Paint()
        ..color = OsdMedia.onMedia
        ..style = PaintingStyle.stroke
        ..strokeWidth = _border,
    );
    final double? at = playhead.value;
    if (at != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(at * size.width, size.height / 2),
            width: _playheadWidth,
            height: size.height - 2 * _playheadInset,
          ),
          const Radius.circular(_playheadWidth / 2),
        ),
        Paint()..color = OsdMedia.onMedia,
      );
    }
  }

  @override
  bool shouldRepaint(TrimWindowPainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.sourceEnd != sourceEnd ||
      oldDelegate.slide != slide ||
      oldDelegate.glow != glow ||
      oldDelegate.playhead != playhead;
}
