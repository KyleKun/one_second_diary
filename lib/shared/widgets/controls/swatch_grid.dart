import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hit_slop.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// Builds the swatch at [index], [diameter] wide.
typedef SwatchBuilder =
    Widget Function(BuildContext context, int index, double diameter);

/// The colour grid: 8 columns, each swatch centred in its cell. When a cell
/// would be too narrow it switches to 6 columns.
///
/// Each swatch's hit area is its cell plus half of each gap, without changing
/// the layout. Nothing is clipped, so selection rings can reach into the
/// gaps.
class SwatchGrid extends StatelessWidget {
  const SwatchGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  static const int _columns = 8;
  static const int _narrowColumns = 6;
  static const double _minCell = 30;
  static const double _maxDiameter = 34;
  static const double _gap = OsdSpace.gridGapSwatches;

  final int itemCount;

  final SwatchBuilder itemBuilder;

  static double _cellFor(double width, int columns) =>
      (width - (columns - 1) * _gap) / columns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      var columns = _columns;
      var cell = _cellFor(width, columns);
      if (cell < _minCell) {
        columns = _narrowColumns;
        cell = _cellFor(width, columns);
      }
      final diameter = math.min(_maxDiameter, cell);
      final rows = (itemCount / columns).ceil();
      final margin = (cell - diameter) / 2;
      // Swatches are direct children of their row, so the row forwards
      // taps in the margins and gaps to them; every ancestor up to the
      // column is as wide as the grid.
      return Column(
        mainAxisSize: MainAxisSize.min,
        spacing: _gap,
        children: <Widget>[
          for (var row = 0; row < rows; row++)
            OsdHitSlop(
              slop: const EdgeInsets.symmetric(vertical: _gap / 2),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: margin),
                child: Row(
                  spacing: 2 * margin + _gap,
                  children: <Widget>[
                    for (
                      var index = row * columns;
                      index < math.min(itemCount, (row + 1) * columns);
                      index++
                    )
                      OsdHitSlop(
                        slop: EdgeInsets.symmetric(
                          horizontal: margin + _gap / 2,
                          vertical: _gap / 2,
                        ),
                        child: SizedBox.square(
                          dimension: diameter,
                          child: itemBuilder(context, index, diameter),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
