// Today's pager: one whole page per clip, and where a release settles.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/today/domain/today_carousel_geometry.dart';

void main() {
  const TodayCarouselGeometry pager = TodayCarouselGeometry(
    viewport: 300,
    count: 3,
  );
  const double stride = 300 + TodayCarouselGeometry.gap;

  test('every page rests a whole page (and the gap) after the one before, so '
      'no neighbour shows', () {
    expect(pager.targetOf(0), 0);
    expect(pager.targetOf(1), stride);
    expect(pager.targetOf(2), 2 * stride);
    expect(pager.maxScroll, 2 * stride);
    expect(pager.positionAt(stride * 1.5), 1.5);
    expect(pager.indexAt(stride * 1.6), 2);
  });

  test('a release settles on the nearest page, a fling on the next one in '
      'its direction, never past the ends', () {
    expect(pager.snapTarget(stride * 1.4, velocity: 0), stride);
    expect(pager.snapTarget(stride * 1.1, velocity: 800), 2 * stride);
    expect(pager.snapTarget(stride * 1.9, velocity: -800), stride);
    expect(pager.snapTarget(2 * stride, velocity: 800), 2 * stride);
    expect(pager.snapTarget(0, velocity: -800), 0);
  });

  test('one clip never scrolls', () {
    const TodayCarouselGeometry one = TodayCarouselGeometry(
      viewport: 300,
      count: 1,
    );
    expect(one.maxScroll, 0);
    expect(one.snapTarget(0, velocity: 800), 0);
  });
}
