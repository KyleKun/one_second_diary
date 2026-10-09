import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_state.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/processing_thumb.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The making page's grid of the movie's clips: 5 columns, with shorter cells
/// on a short phone and cells that keep their shape on a tablet.
class ProcessingGrid extends StatelessWidget {
  const ProcessingGrid({super.key});

  static const Key gridKey = Key('processingGrid');

  static const int columns = 5;

  /// Rows in the window.
  static const int windowRows = 5;

  /// The window keeps the clip in hand on this row (0-based).
  static const int _anchorRow = 2;

  static const double gap = 6;

  /// A cell on a 390 wide phone.
  static const double _cellHeight = 50;
  static const double _cellWidth = 64.4;
  static const double _shortCellHeight = 40;

  /// Below this height a phone takes the short cells.
  static const double _shortScreen = 700;

  /// The ring and the 1.08 scale reach this far out of a cell.
  static const double _cellOverflow = 5;

  /// The row of the clip the window follows in [job]: the one in hand, or
  /// the last done.
  static int _followedRow(MovieJobState job) {
    final int index =
        job.currentIndex ??
        math.max(0, math.min(job.processed, job.clips.length) - 1);
    return index ~/ columns;
  }

  @override
  Widget build(BuildContext context) {
    final List<ClipRef> clips = context.select<MovieJobBloc, List<ClipRef>>(
      (MovieJobBloc job) => job.state.clips,
    );
    final VideoOrientation orientation = context
        .select<MovieJobBloc, VideoOrientation>(
          (MovieJobBloc job) =>
              job.state.request?.orientation ?? VideoOrientation.landscape,
        );
    final int rows = (clips.length / columns).ceil();
    final int firstRow = context.select<MovieJobBloc, int>(
      (MovieJobBloc job) => rows <= windowRows
          ? 0
          : (_followedRow(job.state) - _anchorRow).clamp(0, rows - windowRows),
    );
    final bool short = MediaQuery.sizeOf(context).height < _shortScreen;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cellWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        final double cellHeight = short
            ? _shortCellHeight
            : math.max(_cellHeight, cellWidth * _cellHeight / _cellWidth);
        final int shownRows = math.min(rows, windowRows);
        return RepaintBoundary(
          child: ExcludeSemantics(
            child: SizedBox(
              key: gridKey,
              height: shownRows == 0
                  ? 0
                  : shownRows * cellHeight + (shownRows - 1) * gap,
              child: ClipRect(
                clipper: const _OverflowClipper(_cellOverflow),
                child: _Window(
                  clips: clips,
                  orientation: orientation,
                  rows: rows,
                  firstRow: firstRow,
                  cellWidth: cellWidth,
                  cellHeight: cellHeight,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The rows of the window from [firstRow], slid up a row at a time as
/// [firstRow] moves (`processing`); while it slides, the rows it leaves stay
/// built, and go once it has.
class _Window extends StatefulWidget {
  const _Window({
    required this.clips,
    required this.orientation,
    required this.rows,
    required this.firstRow,
    required this.cellWidth,
    required this.cellHeight,
  });

  final List<ClipRef> clips;
  final VideoOrientation orientation;
  final int rows;
  final int firstRow;
  final double cellWidth;
  final double cellHeight;

  @override
  State<_Window> createState() => _WindowState();
}

class _WindowState extends State<_Window> with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    value: 1,
  );

  /// The row at the top when the slide started.
  late double _startRow = widget.firstRow.toDouble();

  Curve _curve = OsdMotion.processingCurve;

  /// The row at the top now (a fraction while sliding).
  double get _topRow =>
      _startRow +
      (widget.firstRow - _startRow) * _curve.transform(_slide.value);

  @override
  void didUpdateWidget(_Window oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.firstRow == oldWidget.firstRow) return;
    final double from =
        _startRow +
        (oldWidget.firstRow - _startRow) * _curve.transform(_slide.value);
    _startRow = from;
    _curve = OsdMotion.curve(context, OsdMotion.processingCurve);
    _slide.duration = OsdMotion.d(context, OsdMotion.processing);
    unawaited(
      _slide.forward(from: 0).then((_) {
        // The rows slid out of the window can go.
        if (mounted) setState(() => _startRow = widget.firstRow.toDouble());
      }),
    );
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double extent = widget.cellHeight + ProcessingGrid.gap;
    final int from = math.max(0, math.min(widget.firstRow, _startRow.floor()));
    final int to = math.min(
      widget.rows,
      math.max(widget.firstRow, _startRow.ceil()) + ProcessingGrid.windowRows,
    );
    return AnimatedBuilder(
      animation: _slide,
      builder: (BuildContext context, Widget? rows) => Transform.translate(
        offset: Offset(0, -(_topRow - from) * extent),
        child: rows,
      ),
      child: OverflowBox(
        alignment: AlignmentDirectional.topStart,
        maxHeight: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: ProcessingGrid.gap,
          children: <Widget>[
            for (int row = from; row < to; row++)
              _Row(
                key: ValueKey<int>(row),
                clips: widget.clips,
                orientation: widget.orientation,
                first: row * ProcessingGrid.columns,
                cellWidth: widget.cellWidth,
                cellHeight: widget.cellHeight,
              ),
          ],
        ),
      ),
    );
  }
}

/// A row of 5 cells from clip [first]; the last row starts at the start
/// edge.
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.clips,
    required this.orientation,
    required this.first,
    required this.cellWidth,
    required this.cellHeight,
  });

  final List<ClipRef> clips;
  final VideoOrientation orientation;
  final int first;
  final double cellWidth;
  final double cellHeight;

  @override
  Widget build(BuildContext context) => Row(
    spacing: ProcessingGrid.gap,
    children: <Widget>[
      for (int column = 0; column < ProcessingGrid.columns; column++)
        SizedBox(
          width: cellWidth,
          height: cellHeight,
          child: first + column < clips.length
              ? _Cell(
                  clip: clips[first + column],
                  index: first + column,
                  orientation: orientation,
                )
              : null,
        ),
    ],
  );
}

/// Clip [index]'s cell, following its own state in the job.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.clip,
    required this.index,
    required this.orientation,
  });

  final ClipRef clip;
  final int index;
  final VideoOrientation orientation;

  @override
  Widget build(BuildContext context) {
    final ({bool done, bool current}) cell = context
        .select<MovieJobBloc, ({bool done, bool current})>(
          (MovieJobBloc job) => ProcessingThumb.stateOf(job.state, index),
        );
    return ProcessingThumb(
      key: ProcessingThumb.cellKey(clip),
      clip: clip,
      orientation: orientation,
      done: cell.done,
      current: cell.current,
    );
  }
}

/// Clips to the box grown by [overflow] on every side, so the ring and the
/// scale of a cell at the edge show while the rows beyond stay hidden (the 6 px
/// gaps are wider than [overflow]).
class _OverflowClipper extends CustomClipper<Rect> {
  const _OverflowClipper(this.overflow);

  final double overflow;

  @override
  Rect getClip(Size size) => (Offset.zero & size).inflate(overflow);

  @override
  bool shouldReclip(_OverflowClipper oldClipper) =>
      oldClipper.overflow != overflow;
}
