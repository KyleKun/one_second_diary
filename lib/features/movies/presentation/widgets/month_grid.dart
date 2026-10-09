import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_state.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/shared/widgets/controls/month_tile.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The month sheet's months: January to December of the year shown, each a
/// `MonthTile` with its clips ("31 clips").
class MonthGrid extends StatefulWidget {
  const MonthGrid({super.key});

  /// The tile of [month] (1–12).
  static Key tileKey(int month) => ValueKey<String>('monthGrid.$month');

  @override
  State<MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends State<MonthGrid> {
  static const double _slide = 12;
  static const int _columns = 3;

  /// Which way the year moved last: 1 forward, -1 back.
  int _direction = 1;

  @override
  Widget build(BuildContext context) {
    final int year = context.select<CreateMovieCubit, int>(
      (CreateMovieCubit flow) => _yearOf(flow.state),
    );
    final bool reduced = OsdMotion.reduced(context);
    return BlocListener<CreateMovieCubit, CreateMovieState>(
      listenWhen: (CreateMovieState previous, CreateMovieState current) =>
          _yearOf(previous) != _yearOf(current),
      listener: (BuildContext context, CreateMovieState state) =>
          setState(() => _direction = _yearOf(state) > year ? 1 : -1),
      child: AnimatedSwitcher(
        duration: OsdMotion.d(context, OsdMotion.standard),
        switchInCurve: OsdMotion.curve(context, OsdMotion.standardCurve),
        switchOutCurve: OsdMotion.curve(context, OsdMotion.standardCurve),
        layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[...previous, ?current],
        ),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final bool incoming = child.key == ValueKey<int>(year);
          final double from = (incoming ? 1 : -1) * _direction * _slide;
          return FadeTransition(
            opacity: animation,
            child: reduced
                ? child
                : AnimatedBuilder(
                    animation: animation,
                    builder: (BuildContext context, Widget? child) =>
                        Transform.translate(
                          offset: Offset(from * (1 - animation.value), 0),
                          child: child,
                        ),
                    child: child,
                  ),
          );
        },
        child: _YearMonths(key: ValueKey<int>(year), year: year),
      ),
    );
  }

  static int _yearOf(CreateMovieState state) =>
      state.monthChoice?.year ?? state.today.year;
}

/// The twelve tiles of [year].
class _YearMonths extends StatelessWidget {
  const _YearMonths({super.key, required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    final CreateMovieState state = context.watch<CreateMovieCubit>().state;
    // The clips a movie of the month takes: without the private ones,
    // unless the flow includes them.
    final List<int> clips =
        state.rangeIndex?.clipsPerMonth(year) ?? List<int>.filled(12, 0);
    final int? picked = state.monthChoice?.year == year
        ? state.monthChoice?.month
        : null;
    return Column(
      spacing: 8,
      children: <Widget>[
        for (int row = 0; row < 12 ~/ _MonthGridState._columns; row++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: <Widget>[
                for (
                  int column = 0;
                  column < _MonthGridState._columns;
                  column++
                )
                  Expanded(
                    child: _Month(
                      month: row * _MonthGridState._columns + column + 1,
                      year: year,
                      clips: clips[row * _MonthGridState._columns + column],
                      open: state.isOpen(
                        year,
                        row * _MonthGridState._columns + column + 1,
                      ),
                      selected:
                          picked == row * _MonthGridState._columns + column + 1,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Month extends StatelessWidget {
  const _Month({
    required this.month,
    required this.year,
    required this.clips,
    required this.open,
    required this.selected,
  });

  final int month;
  final int year;
  final int clips;
  final bool open;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bool none = clips == 0 || (!open && _isFuture(context));
    final String count = none
        ? '—'
        : Strings.clipCount(clips, format: MovieLabels.numberFormat(context));
    return MonthTile(
      key: MonthGrid.tileKey(month),
      month: MovieLabels.shortMonth(context, month),
      count: count,
      selected: selected,
      semanticsLabel:
          '${MovieLabels.month(context, month)}, '
          '${none ? Strings.monthNoClips : count}',
      onTap: open
          ? () => context.read<CreateMovieCubit>().pickMonth(month)
          : null,
    );
  }

  bool _isFuture(BuildContext context) {
    final CreateMovieState state = context.read<CreateMovieCubit>().state;
    return year > state.today.year ||
        (year == state.today.year && month > state.today.month);
  }
}
