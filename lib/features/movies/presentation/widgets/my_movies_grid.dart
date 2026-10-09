import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/my_movies_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/my_movies_state.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_grid_item.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// My movies' grid: a lazy sliver of [MovieGridItem]s, 2 columns on a phone and
/// up to 5 on a tablet; in the large view (`MyMoviesState.largeView`) one movie
/// a row, as Memories shows days, two on a wide tablet.
class MyMoviesGrid extends StatefulWidget {
  const MyMoviesGrid({super.key});

  /// The widest a column is laid out for before another is added.
  static const double _columnTarget = 180;
  static const int _minColumns = 2;
  static const int _maxColumns = 5;

  /// The same for the large view.
  static const double _largeColumnTarget = 420;
  static const int _largeMinColumns = 1;
  static const int _largeMaxColumns = 2;

  /// The shrink of a movie leaving.
  static const double _leavingScale = .9;

  @override
  State<MyMoviesGrid> createState() => _MyMoviesGridState();
}

class _MyMoviesGridState extends State<MyMoviesGrid> {
  /// The movies the grid shows, to tell which left.
  late List<MovieEntry> _shown;

  /// A new key rebuilds the grid from scratch (movies added: a reload).
  GlobalKey<SliverAnimatedGridState> _grid =
      GlobalKey<SliverAnimatedGridState>();

  @override
  void initState() {
    super.initState();
    _shown = context.read<MyMoviesCubit>().state.visibleMovies;
  }

  /// Animates the movies that left out of the grid; anything else that
  /// changed the list's shape starts the grid over.
  void _onMovies(BuildContext context, MyMoviesState state) {
    final List<MovieEntry> previous = _shown;
    final List<MovieEntry> next = state.visibleMovies;
    _shown = next;
    final Set<String> kept = <String>{
      for (final MovieEntry movie in next) movie.fileName,
    };
    final List<int> left = <int>[
      for (int i = previous.length - 1; i >= 0; i--)
        if (!kept.contains(previous[i].fileName)) i,
    ];
    final SliverAnimatedGridState? grid = _grid.currentState;
    if (grid == null || previous.length - left.length != next.length) {
      setState(() => _grid = GlobalKey<SliverAnimatedGridState>());
      return;
    }
    final Duration duration = OsdMotion.d(context, OsdMotion.standard);
    for (final int index in left) {
      final MovieEntry movie = previous[index];
      grid.removeItem(
        index,
        (BuildContext context, Animation<double> animation) => _Leaving(
          movie: movie,
          large: state.largeView,
          animation: animation,
        ),
        duration: duration,
      );
    }
  }

  /// The styles and text size [_lines] was measured for.
  ({TextStyle title, TextStyle count, TextScaler scaler, int titleLines})?
  _linesFor;
  double _lines = 0;

  /// The title and the count lines at the text size in use, with their gaps: an
  /// item's height past its poster, measured once per text size.
  double _textExtent(BuildContext context, {required bool large}) {
    final OsdTypography typography = context.typography;
    final ({
      TextStyle title,
      TextStyle count,
      TextScaler scaler,
      int titleLines,
    })
    key = (
      title: MovieGridItem.titleStyle(typography, large: large),
      count: typography.caption,
      scaler: MediaQuery.textScalerOf(context),
      titleLines: OsdTextScale.nameLines(context),
    );
    if (key != _linesFor) {
      _linesFor = key;
      _lines =
          MovieGridItem.posterGap +
          _lineHeight(key.title, key.scaler, lines: key.titleLines) +
          MovieGridItem.countGap +
          _lineHeight(key.count, key.scaler);
    }
    return _lines;
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<MyMoviesCubit, MyMoviesState>(
        listenWhen: (MyMoviesState previous, MyMoviesState current) =>
            !identical(previous.visibleMovies, current.visibleMovies),
        listener: _onMovies,
        child: BlocBuilder<MyMoviesCubit, MyMoviesState>(
          buildWhen: (MyMoviesState previous, MyMoviesState current) =>
              !identical(previous.visibleMovies, current.visibleMovies) ||
              previous.largeView != current.largeView,
          builder: (BuildContext context, MyMoviesState state) =>
              SliverAnimatedGrid(
                key: _grid,
                initialItemCount: state.visibleMovies.length,
                gridDelegate: _MoviesLayout(
                  textExtent: _textExtent(context, large: state.largeView),
                  large: state.largeView,
                ),
                itemBuilder:
                    (
                      BuildContext context,
                      int index,
                      Animation<double> animation,
                    ) {
                      final MovieEntry movie = context
                          .read<MyMoviesCubit>()
                          .state
                          .visibleMovies[index];
                      return MovieGridItem(
                        key: MovieGridItem.itemKey(movie.fileName),
                        movie: movie,
                        large: state.largeView,
                      );
                    },
              ),
        ),
      );

  static double _lineHeight(
    TextStyle style,
    TextScaler scaler, {
    int lines = 1,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: List<String>.filled(lines, 'Mg').join('\n'),
        style: style,
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: lines,
    )..layout();
    final double height = painter.height;
    painter.dispose();
    return math.max(0, height).ceilToDouble();
  }
}

/// The grid's columns, worked out at layout time from the width the sliver is
/// given, so a scroll lays the grid out again without building it; each item is
/// a 16:9 poster over [textExtent].
class _MoviesLayout extends SliverGridDelegate {
  const _MoviesLayout({required this.textExtent, required this.large});

  /// An item's height past its poster.
  final double textExtent;

  /// Whether the movies show large.
  final bool large;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final double width = constraints.crossAxisExtent;
    final double target = large
        ? MyMoviesGrid._largeColumnTarget
        : MyMoviesGrid._columnTarget;
    final int columns =
        ((width + OsdSpace.gridGapMoviesH) / (target + OsdSpace.gridGapMoviesH))
            .floor()
            .clamp(
              large ? MyMoviesGrid._largeMinColumns : MyMoviesGrid._minColumns,
              large ? MyMoviesGrid._largeMaxColumns : MyMoviesGrid._maxColumns,
            );
    final double column =
        (width - OsdSpace.gridGapMoviesH * (columns - 1)) / columns;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: OsdSpace.gridGapMoviesH,
      mainAxisSpacing: OsdSpace.gridGapMoviesV,
      mainAxisExtent: column * 9 / 16 + textExtent,
    ).getLayout(constraints);
  }

  @override
  bool shouldRelayout(_MoviesLayout oldDelegate) =>
      oldDelegate.textExtent != textExtent || oldDelegate.large != large;
}

/// A deleted movie leaving its cell: it fades and shrinks; under reduced
/// motion it only fades.
class _Leaving extends StatelessWidget {
  const _Leaving({
    required this.movie,
    required this.large,
    required this.animation,
  });

  final MovieEntry movie;
  final bool large;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final Widget item = MovieGridItem(movie: movie, large: large);
    return IgnorePointer(
      child: FadeTransition(
        opacity: animation,
        child: OsdMotion.reduced(context)
            ? item
            : ScaleTransition(
                scale: Tween<double>(
                  begin: MyMoviesGrid._leavingScale,
                  end: 1,
                ).animate(animation),
                child: item,
              ),
      ),
    );
  }
}
