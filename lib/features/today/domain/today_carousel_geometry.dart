import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Where the pager's pages sit on the stage and where the pager snaps.
///
/// Every page is as wide as the stage ([viewport]), so one
/// clip shows at a time, whole: its neighbours never peek. Two pages are a
/// [gap] apart, which only shows during a swipe.
final class TodayCarouselGeometry extends Equatable {
  const TodayCarouselGeometry({required this.viewport, required this.count});

  /// The space between two pages.
  static const double gap = 10;

  /// A release faster than this (px/s) turns the page.
  static const double flingVelocity = 300;

  /// The stage's width: a page's width.
  final double viewport;

  final int count;

  /// From one page's start to the next one's.
  double get _stride => viewport + gap;

  int get _last => math.max(0, count - 1);

  /// The furthest the pager scrolls: the last page in view.
  double get maxScroll => _last * _stride;

  /// The scroll offset that shows page [index].
  double targetOf(int index) => math.min(index * _stride, maxScroll);

  /// Where [offset] is, in pages: 1 at page 1's target, 1.5 halfway to
  /// page 2's.
  double positionAt(double offset) =>
      (offset / _stride).clamp(0, _last).toDouble();

  /// The page nearest [offset]: the one in view, which Edit acts on.
  int indexAt(double offset) => positionAt(offset).round();

  /// Where a release at [offset] settles: with a fling ([velocity] faster
  /// than [flingVelocity]) the next page in its direction, else the nearest
  /// page.
  double snapTarget(double offset, {required double velocity}) {
    final double position = positionAt(offset);
    final int index = velocity > flingVelocity
        ? position.floor() + 1
        : velocity < -flingVelocity
        ? position.ceil() - 1
        : position.round();
    return targetOf(index.clamp(0, _last));
  }

  @override
  List<Object?> get props => <Object?>[viewport, count];
}
